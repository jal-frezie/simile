<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.1" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

<xsl:output method="text" indent="no"/>
<xsl:strip-space elements="*"/>


<xsl:variable name="indents">
   <indent level="0" value=""/>
   <indent level="1" value="   "/>
   <indent level="2" value="      "/>
   <indent level="3" value="         "/>
   <indent level="4" value="            "/>
   <indent level="5" value="               "/>
   <indent level="6" value="                  "/>
   <indent level="7" value="                     "/>
   <indent level="8" value="                        "/>
   <indent level="9" value="                           "/>
</xsl:variable>


<!-- This is the top-level template -->
<xsl:template match="/">
   <xsl:text/>document(<xsl:text/>
   <xsl:apply-templates select="*"/>
   <xsl:text/>).<xsl:text/>
</xsl:template>


<!-- This is the main template, that handles the elements.
     It calls itself recursively as it moves down the tree. -->
<xsl:template match="*">
   <xsl:param name="level" select="count(./ancestor::*)"/>

   <xsl:text>
</xsl:text>
   <xsl:value-of select="$indents/indent[@level=$level]/@value"/>
   <xsl:text/>element(<xsl:value-of select="local-name(.)"/>,[<xsl:text/>

   <!--Process attributes.  -->
   <xsl:apply-templates select="@*">
      <xsl:with-param name="element" select="."/>
      <xsl:with-param name="level" select="$level"/>
   </xsl:apply-templates>
  
   <xsl:text>],</xsl:text>

   <!-- Process the element's value.  -->
   <xsl:text/>"<xsl:text/>
      <xsl:if test="not(*)">
         <xsl:value-of select="."/>
      </xsl:if>
   <xsl:text/>"<xsl:text/>

   <!-- Process children -->
   <xsl:text>,[</xsl:text>
   <xsl:apply-templates select="*">
      <xsl:with-param name="level" select="$level + 1"/>
   </xsl:apply-templates>
   <xsl:text/>])<xsl:text/>
   <xsl:if test="position() != last()">
      <xsl:text/>,<xsl:text/>
   </xsl:if>

</xsl:template>


<!-- This is the template for handling the element attributes -->
<xsl:template match="@*">
   <xsl:value-of select="local-name(.)"/>="<xsl:value-of select="."/>"<xsl:text/>
   <xsl:if test="position() != last()">
      <xsl:text/>,<xsl:text/>
   </xsl:if>
</xsl:template>

</xsl:stylesheet>
