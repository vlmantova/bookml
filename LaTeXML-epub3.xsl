<?xml version="1.0" encoding="utf-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:import href="bookml/XSLT/bookml-epub3.xsl"/>

  <!-- omit content with 'noepub' class -->
  <xsl:template mode="bml-alter"
    match="*[contains(concat(' ',@class,' '),' noepub ')]" />
</xsl:stylesheet>
