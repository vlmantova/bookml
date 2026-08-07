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
  xmlns:svg="http://www.w3.org/2000/svg"
  xmlns:b="https://vlmantova.github.io/bookml/functions"
  xmlns:func="http://exslt.org/functions"
  extension-element-prefixes="func"
  exclude-result-prefixes="svg">

  <xsl:import href="utils.xsl"/>

  <xsl:param name="SVGCONVERTER" />

  <func:function name="b:mutool">
    <func:result select="$SVGCONVERTER = 'mutool'" />
  </func:function>

  <xsl:output
    method="xml"
    encoding="utf-8" />

  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

  <!-- CSS pixels satisfy 1in = 96px -->
  <!-- dvisvgm and pdftocairo return the size in big points with unit pt -->
  <!-- inkscape returns the size already converted to pixels correctly, without units -->
  <!-- mutool returns the size in big points (1in = 72bp) without units -->

  <xsl:template match="/svg:svg/@width[b:ends-with(.,'pt') or b:mutool()] | /svg:svg/@height[b:ends-with(.,'pt') or b:mutool()]">
    <xsl:variable name="size">
      <xsl:choose>
        <xsl:when test="b:ends-with(.,'pt')"><xsl:value-of select="substring-before(.,'pt')"/></xsl:when>
        <xsl:otherwise><xsl:value-of select="."/></xsl:otherwise>
      </xsl:choose>
    </xsl:variable>
    <xsl:attribute name="{local-name()}">
      <xsl:value-of select="format-number(number($size) * 96 div 72, '#.###')"/>
    </xsl:attribute>
  </xsl:template>

</xsl:stylesheet>
