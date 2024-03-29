package fr.ensimag.twitter_weather;

import org.w3c.dom.Document;
import org.w3c.dom.NamedNodeMap;
import org.w3c.dom.Node;
import org.w3c.dom.NodeList;
import org.xml.sax.SAXException;

import javax.xml.parsers.DocumentBuilder;
import javax.xml.parsers.DocumentBuilderFactory;
import javax.xml.parsers.ParserConfigurationException;
import java.io.IOException;
import java.util.HashMap;
import java.util.Map;

/**
 * A class that analyzes feelings based on emojis
 */
public class FeelingAnalyzer {
    private static final String[] languages = new String[]{"en", "fr"};
    private static FeelingAnalyzer instance;
    private Map<String, Map<Integer, String[]>> feelingMap;
    private Map<String, Map<String, Integer>> wordValueMap;

    private FeelingAnalyzer() throws ParserConfigurationException, IOException, SAXException {
        feelingMap = new HashMap<String, Map<Integer, String[]>>();
        wordValueMap = new HashMap<String, Map<String, Integer>>();

        DocumentBuilderFactory builderFactory = DocumentBuilderFactory.newInstance();
        DocumentBuilder builder = builderFactory.newDocumentBuilder();

        for (String language : languages) {
            // Parse the annotations
            Document doc = builder.parse(getClass().getResourceAsStream(String.format("/annotations/%s.xml", language)));

            Map<Integer, String[]> langDict = feelingMap.get(language);
            if (langDict == null) {
                langDict = new HashMap<Integer, String[]>();
                feelingMap.put(language, langDict);
            }

            NodeList annotations = doc.getDocumentElement().getElementsByTagName("annotations").item(0).getChildNodes();
            for (int i = 0; i < annotations.getLength(); ++i) {
                Node item = annotations.item(i);
                if (item.getNodeName().equals("annotation")) {
                    NamedNodeMap attributes = item.getAttributes();
                    if (attributes.getNamedItem("tts") == null) {
                        langDict.put(attributes.getNamedItem("cp").getNodeValue().codePointAt(0),
                            item.getTextContent().split(" \\| "));
                    }
                }
            }

            // Parse the value maps
            doc = builder.parse(getClass().getResourceAsStream(String.format("/valueMaps/%s.xml", language)));

            Map<String, Integer> valueMap = wordValueMap.get(language);
            if (valueMap == null) {
                valueMap = new HashMap<String, Integer>();
                wordValueMap.put(language, valueMap);
            }

            NodeList words = doc.getDocumentElement().getElementsByTagName("word");
            for (int i = 0; i < words.getLength(); ++i) {
                Node item = words.item(i);
                valueMap.put(item.getTextContent(), Integer.parseInt(item.getAttributes().getNamedItem("value").getNodeValue()));
            }
        }
    }

    public static FeelingAnalyzer getInstance() {
        if (instance == null) {
            try {
                instance = new FeelingAnalyzer();
            } catch (ParserConfigurationException e) {
                throw new RuntimeException(e);
            } catch (SAXException e) {
                throw new RuntimeException(e);
            } catch (IOException e) {
                throw new RuntimeException(e);
            }
        }

        return instance;
    }

    public Map<String, String> getFeelingProperties(String language, String tweetText) {
        // Output property map
        Map<String, String> ret = new HashMap<String, String>();

        // First, build the emoji-decoded version of the text
        StringBuilder sb = new StringBuilder();

        // Get the default language dict and value map
        Map<Integer, String[]> langDict = feelingMap.get(language);
        Map<String, Integer> valueMap = wordValueMap.get(language);
        if (langDict == null)
            langDict = feelingMap.get(languages[0]);
        if (valueMap == null)
            valueMap = wordValueMap.get(languages[0]);

        int emojiCount = 0, totalCharCount = 0;
        Map<Integer, Integer> seenEmoji = new HashMap<Integer, Integer>();

        boolean lastCharWasSeparator = true;
        for (int i = 0; i < tweetText.length(); ) {
            int cp = tweetText.codePointAt(i);
            i += Character.charCount(cp);

            String[] value = langDict.get(cp);

            if (value == null) {
                if (!Character.isLetterOrDigit(cp)) {
                    if (!lastCharWasSeparator) {
                        sb.append(' ');
                        lastCharWasSeparator = true;
                    }
                } else {
                    // not an emoji
                    sb.appendCodePoint(Character.toLowerCase(cp));
                    totalCharCount++;
                    lastCharWasSeparator = false;
                }
            } else {
                // an emoji
                if (!lastCharWasSeparator) {
                    sb.append(' ');
                }

                if (!seenEmoji.containsKey(cp))
                    seenEmoji.put(cp, 1);
                else
                    seenEmoji.put(cp, seenEmoji.get(cp) + 1);

                emojiCount++;
                totalCharCount++;

                for (int j = 0; j < value.length; ++j) {
                    sb.append(value[j]);
                    if (j < value.length - 1) {
                        sb.append(' ');
                    }
                }

                lastCharWasSeparator = false;
            }
        }

        // Build the final string
        String decoded = sb.toString();

        // Compute feeling level
        int level = 0;
        for (String word : decoded.split(" ")) {
            Integer value = valueMap.get(word);
            if (value != null) {
                level += value;
            }
        }

        // Append properties
        ret.put("level", Integer.toString(level));

        ret.put("char_count", Integer.toString(totalCharCount));
        ret.put("emoji_count", Integer.toString(emojiCount));

        ret.put("unique_emoji_count", Integer.toString(seenEmoji.size()));

        Integer keyMax = 0;
        Integer valueMax = 0;
        for (Map.Entry<Integer, Integer> kv : seenEmoji.entrySet()) {
            if (kv.getValue() > valueMax) {
                keyMax = kv.getKey();
                valueMax = kv.getValue();
            }
        }
        if (keyMax != 0) {
            ret.put("most_used_emoji", new String(Character.toChars(keyMax)));
        } else {
            ret.put("most_used_emoji", "");
        }
        ret.put("most_used_emoji_count", Integer.toString(valueMax));

        // Decoded text
        ret.put("text", decoded);

        // No error
        ret.put("error", "");

        return ret;
    }
}
