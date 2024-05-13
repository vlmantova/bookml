<?xml version="1.0" encoding="utf-8"?>
<!--

  BookML: bookdown flavoured GitBook port for LaTeXML
  Copyright (C) 2021-23 Vincenzo Mantova <v.l.mantova@leeds.ac.uk>

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
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">

  <xsl:output
    method="text"
    encoding="utf-8" />

  <xsl:template match="/">
    <xsl:variable name="output">
      <xsl:apply-templates select="//body" />
    </xsl:variable>
    <xsl:value-of select="normalize-space($output)"/>
  </xsl:template>

  <xsl:template match="*[@alt | @alttext | @aria-label]">
    <xsl:value-of select="concat(' ',string(@alt | @alttext | @aria-label),' ')"/>
  </xsl:template>

  <xsl:template match="annotation | nav | script | style" />

</xsl:stylesheet>
