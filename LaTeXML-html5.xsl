<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:import href="bookml/XSLT/bookml-html5.xsl" />

  <!-- remove class 'epub' -->
  <xsl:template mode="bml-alter"
    match="@class[contains(concat(' ',.,' '),' noepub ')]">
    <xsl:variable name="oldclass" select="concat(' ',.,' ')" />
    <xsl:variable name="preclass" select="substring-before($oldclass,' noepub ')" />
    <xsl:variable name="postclass" select="substring-after($oldclass,' noepub ')" />
    <xsl:variable name="newclass" select="normalize-space(concat($preclass,' ',$postclass))" />
    <xsl:if test="$newclass">
      <xsl:attribute name="class">
        <xsl:value-of select="$newclass" />
      </xsl:attribute>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>
