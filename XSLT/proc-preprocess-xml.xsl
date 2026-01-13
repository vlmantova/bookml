<?xml version="1.0" encoding="utf-8"?>
<!--

  BookML: bookdown flavoured GitBook port for LaTeXML
  Copyright (C) 2021-25 Vincenzo Mantova <v.l.mantova@leeds.ac.uk>

  This program is free software: you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation, either version 3 of the License, or
  (at your option) any later version.

  This program is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
  GNU General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with this program.  If not, see <https://www.gnu.org/licenses/>.

-->
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform"
  xmlns:ltx="http://dlmf.nist.gov/LaTeXML"
  xmlns:b="https://vlmantova.github.io/bookml/functions"
  xmlns:str="http://exslt.org/strings"
  extension-element-prefixes="str">

  <xsl:import href="utils.xsl" />

  <xsl:output
    method="xml"
    encoding="utf-8" />

  <xsl:param name="AUX_DIR" />

  <!-- make a copy of the XML file with selected alterations -->
  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()" />
    </xsl:copy>
  </xsl:template>

  <xsl:template match="/">
    <xsl:processing-instruction name="latexml">
      <xsl:text>searchpaths="</xsl:text>
      <xsl:value-of select="$AUX_DIR" />
      <xsl:text>/images"</xsl:text>
    </xsl:processing-instruction>
    <xsl:apply-templates />
  </xsl:template>

  <!-- replace PDF, EPS images with auto-generated SVGs if no other candidates are available -->
  <xsl:template match="ltx:graphics/@candidates[b:auto-svg()]">
    <xsl:variable name="svg-candidate" select="b:auto-svg-candidate()"/>
    <xsl:attribute name="candidates">
      <xsl:choose>
        <xsl:when test="$svg-candidate = ''">
          <xsl:value-of select="."/>
        </xsl:when>
        <xsl:otherwise>
          <xsl:value-of select="$svg-candidate" />
        </xsl:otherwise>
      </xsl:choose>
    </xsl:attribute>
  </xsl:template>

</xsl:stylesheet>
