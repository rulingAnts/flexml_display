<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="html" encoding="UTF-8" indent="yes"/>
  
  <!-- Parameter for visible languages (comma-separated list, e.g., "en,es,fr") -->
  <xsl:param name="visibleLangs" select="''"/>

  <!-- Root template -->
  <xsl:template match="/">
    <xsl:apply-templates select="list | List"/>
  </xsl:template>

  <!-- Template for list element -->
  <xsl:template match="list | List">
    <div>
      <!-- Title from Name/AUni elements -->
      <div class="section-title">
        <xsl:choose>
          <xsl:when test="Name/AUni[@ws='en']">
            <xsl:value-of select="normalize-space(Name/AUni[@ws='en'])"/>
          </xsl:when>
          <xsl:when test="Name/AUni">
            <xsl:value-of select="normalize-space(Name/AUni[1])"/>
          </xsl:when>
          <xsl:when test="Name">
            <xsl:value-of select="normalize-space(Name)"/>
          </xsl:when>
          <xsl:when test="name">
            <xsl:value-of select="normalize-space(name)"/>
          </xsl:when>
          <xsl:otherwise>Translated List</xsl:otherwise>
        </xsl:choose>
      </div>

      <!-- Language controls placeholder (managed by JavaScript) -->
      <div class="lang-controls"></div>

      <!-- List items container -->
      <div class="list-container">
        <ul class="tree">
          <xsl:apply-templates select="Possibilities/* | possibilities/*"/>
        </ul>
      </div>
    </div>
  </xsl:template>

  <!-- Template for list items (possibilities) -->
  <xsl:template match="*[parent::Possibilities or parent::possibilities or parent::SubPossibilities or parent::SubPossibility]">
    <li>
      <!-- Toggle indicator -->
      <xsl:variable name="has-children" select="count(SubPossibilities/* | SubPossibility/* | Possibilities/*) &gt; 0"/>
      <span class="toggle">
        <xsl:if test="$has-children">
          <xsl:attribute name="style">cursor: pointer</xsl:attribute>
        </xsl:if>
        <xsl:choose>
          <xsl:when test="$has-children">▾</xsl:when>
          <xsl:otherwise><xsl:text> </xsl:text></xsl:otherwise>
        </xsl:choose>
      </span>

      <!-- Multilingual content -->
      <span>
        <xsl:call-template name="render-multilingual">
          <xsl:with-param name="names" select="Name | name"/>
          <xsl:with-param name="abbrs" select="Abbreviation | abbr"/>
        </xsl:call-template>
      </span>

      <!-- Nested items -->
      <xsl:if test="$has-children">
        <ul class="tree">
          <xsl:apply-templates select="SubPossibilities/* | SubPossibility/* | Possibilities/*"/>
        </ul>
      </xsl:if>
    </li>
  </xsl:template>

  <!-- Template to render multilingual names and abbreviations -->
  <xsl:template name="render-multilingual">
    <xsl:param name="names"/>
    <xsl:param name="abbrs"/>
    
    <xsl:choose>
      <xsl:when test="$names/AUni">
        <!-- Display AUni elements for visible languages -->
        <xsl:variable name="name-aunis" select="$names/AUni"/>
        
        <!-- Main translation (first visible language or first AUni) -->
        <xsl:variable name="main">
          <xsl:choose>
            <xsl:when test="$visibleLangs != ''">
              <xsl:call-template name="get-first-visible-auni">
                <xsl:with-param name="aunis" select="$name-aunis"/>
                <xsl:with-param name="langs" select="$visibleLangs"/>
              </xsl:call-template>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="normalize-space($name-aunis[1])"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:variable>
        
        <span class="translation-main">
          <xsl:value-of select="$main"/>
        </span>
        
        <!-- Other translations (simplified - show all others) -->
        <xsl:for-each select="$name-aunis[position() &gt; 1]">
          <xsl:if test="normalize-space(.) != '' and normalize-space(.) != $main">
            <xsl:text> · </xsl:text>
            <span class="translation-others">
              <xsl:value-of select="normalize-space(.)"/>
            </span>
          </xsl:if>
        </xsl:for-each>
        
        <!-- Abbreviations -->
        <xsl:if test="$abbrs/AUni[normalize-space(.) != '']">
          <xsl:text> </xsl:text>
          <span class="small-muted">
            <xsl:text>[</xsl:text>
            <xsl:for-each select="$abbrs/AUni[normalize-space(.) != '']">
              <xsl:if test="position() &gt; 1"> / </xsl:if>
              <xsl:value-of select="normalize-space(.)"/>
            </xsl:for-each>
            <xsl:text>]</xsl:text>
          </span>
        </xsl:if>
      </xsl:when>
      <xsl:when test="$names">
        <xsl:value-of select="normalize-space($names)"/>
      </xsl:when>
      <xsl:otherwise>(unnamed)</xsl:otherwise>
    </xsl:choose>
  </xsl:template>

  <!-- Helper template to get first visible AUni -->
  <xsl:template name="get-first-visible-auni">
    <xsl:param name="aunis"/>
    <xsl:param name="langs"/>
    
    <!-- For simplicity, just return the first AUni -->
    <!-- A more complete implementation would parse the langs parameter and match ws attributes -->
    <xsl:value-of select="normalize-space($aunis[1])"/>
  </xsl:template>

</xsl:stylesheet>
