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
  exclude-result-prefixes="b svg">

  <xsl:import href="utils.xsl"/>

  <xsl:output
    method="xml"
    encoding="utf-8" />

  <xsl:template match="@*|node()">
    <xsl:copy>
      <xsl:apply-templates select="@*|node()"/>
    </xsl:copy>
  </xsl:template>

  <!-- dvisvgm returns the size in TeX points (1in = 72.27pt), we want CSS pixels (1in = 96px) -->
  <xsl:template match="/svg:svg/@width[b:ends-with(.,'pt')] | /svg:svg/@height[b:ends-with(.,'pt')]">
    <xsl:attribute name="{local-name()}">
      <xsl:value-of select="format-number(number(substring-before(.,'pt')) * 96 div 72.27, '#.###')"/>
    </xsl:attribute>
  </xsl:template>

</xsl:stylesheet>
