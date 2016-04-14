/**
 * XML parser for configuration parameters.
 * 
 * This maps configuration parameters to a HashMap and are retrieved
 * through the following getter methods:
 *
 * 	public String getLogFile() 
 * 	public String getDocumentRoot() 
 * 	public String getDefaultDocument() 
 * 	public String getServerName() 
 *
 * Usage:
 * 	Configuration config = new Configuration(<XML configuration file>);
 *
 *	config.getLogFile();
 *	config.getDocumentRoot();
 *	config.getDefaultDocument();
 *	config.getServerName();
 */



/*
    MODIFIED by Talus Baddley
    to add the getPortNumber() method.
*/



import java.io.*;

import org.xml.sax.*;
import org.xml.sax.helpers.DefaultHandler;

import javax.xml.parsers.SAXParserFactory;
import javax.xml.parsers.ParserConfigurationException;
import javax.xml.parsers.SAXParser;

import java.util.Map;
import java.util.HashMap;

public class Configuration extends DefaultHandler
{
    private Map<String, String>  map;
    private String configurationFile;

    /**
     * @param File configurationFile - The name of the configuration file
     */ 
    public Configuration(String configurationFile) throws ConfigurationException {
	this.configurationFile = configurationFile;

	map = new HashMap<String, String>();

	try {        
        	// Use the default (non-validating) parser
        	SAXParserFactory factory = SAXParserFactory.newInstance();

        	// Parse the input
        	SAXParser saxParser = factory.newSAXParser();
        	saxParser.parse( new File(configurationFile), this);
	}
	catch (javax.xml.parsers.ParserConfigurationException pce) {
		throw new ConfigurationException("javax.xml.parsers.ParserConfigurationException");
	}
	catch (org.xml.sax.SAXException se) {
		throw new ConfigurationException("org.xml.sax.SAXException");
	}
	catch (java.io.IOException ioe) {
		throw new ConfigurationException("java.io.IOException");
	}
    }


	/**
	 * We will map each configuration attribute to its value
	 * 
	 * @param namespaceURI the namespace
	 * @param lName the local name of the element
	 * @param qName the qualified name of the element
	 * @param attrs the set of attributess associated with the element
 	 */
    public void startElement(String namespaceURI,
                             String lName, 	
                             String qName, 	
                             Attributes attrs)	
    throws SAXException
    {
        String elementName = lName; // element name
        if ("".equals(elementName)) 
		elementName = qName; // namespaceAware = false

	/**
	 * Get the attributes associated with this ELEMENT.
 	 * Attributes are name/value pairs and are stored by index.
	 */
        if (attrs != null) {
            for (int i = 0; i < attrs.getLength(); i++) {
                String aName = attrs.getLocalName(i); // Attr name 
                if ("".equals(aName)) 
			aName = attrs.getQName(i);

		// map the element.attribute to its value
		map.put(elementName+"."+aName,attrs.getValue(i));
            }
        }
    }

	// getter methods for mapped configuration values

	/** Returns the location of the log file */
	public String getLogFile() {
		return map.get("logfile.log");
	}

	/** Returns the location of the document base */
	public String getDocumentRoot() {
		return map.get("context.documentRoot");
	}

	/** Returns the name of the default document */
	public String getDefaultDocument() {
		return map.get("context.defaultDocument");
	}

	/** Returns the name of the server */
	public String getServerName() {
		return map.get("webserver.title");
	}
    
    /** Returns the server's port number */
    public Integer getPortNumber() {
        String listedPort = map.get("context.port");
        if (listedPort == null) return null;
        return new Integer(listedPort);
    }
    
    public String getDirectoryDefaultDocument() {
        return map.get("context.directoryDefaultDocument");
    }
}
