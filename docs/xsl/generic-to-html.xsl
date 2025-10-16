<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="html" encoding="UTF-8" indent="yes"/>
  
  <!-- Parameter to control showing element names -->
  <xsl:param name="showNames" select="'false'"/>

  <!-- Root template -->
  <xsl:template match="/">
    <div>
      <div class="section-title">Generic XML View</div>
      <ul class="tree">
        <xsl:apply-templates select="*"/>
      </ul>
    </div>
  </xsl:template>

  <!-- Template for all elements -->
  <xsl:template match="*">
    <li>
      <xsl:attribute name="data-gen-label">
        <xsl:value-of select="local-name()"/>
      </xsl:attribute>

      <!-- Toggle indicator -->
      <xsl:variable name="has-children" select="count(*) &gt; 0 or normalize-space(text()) != ''"/>
      <span class="toggle">
        <xsl:if test="$has-children">
          <xsl:attribute name="style">cursor: pointer</xsl:attribute>
        </xsl:if>
        <xsl:choose>
          <xsl:when test="$has-children">▾</xsl:when>
          <xsl:otherwise><xsl:text> </xsl:text></xsl:otherwise>
        </xsl:choose>
      </span>

      <!-- Element name label (if showNames is true) -->
      <xsl:if test="$showNames = 'true'">
        <span style="font-weight: 600">
          <xsl:value-of select="local-name()"/>
          <xsl:text>: </xsl:text>
        </span>
      </xsl:if>

      <!-- Handle content -->
      <xsl:choose>
        <!-- If element has only text content (no child elements) -->
        <xsl:when test="not(*) and normalize-space(text()) != ''">
          <span>
            <xsl:value-of select="normalize-space(text())"/>
          </span>
        </xsl:when>
        <!-- If element has child elements -->
        <xsl:when test="*">
          <ul class="tree">
            <xsl:apply-templates select="*"/>
          </ul>
        </xsl:when>
      </xsl:choose>
    </li>
  </xsl:template>

  <!-- Template for text nodes -->
  <xsl:template match="text()">
    <xsl:if test="normalize-space(.) != ''">
      <li>
        <span class="toggle">
          <xsl:text> </xsl:text>
        </span>
        <xsl:value-of select="normalize-space(.)"/>
      </li>
    </xsl:if>
  </xsl:template>

</xsl:stylesheet>
