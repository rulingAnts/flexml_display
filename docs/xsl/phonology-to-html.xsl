<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="html" encoding="UTF-8" indent="yes"/>

  <!-- Root template -->
  <xsl:template match="/phonology | /Phonology">
    <div>
      <div class="section-title">Phonology Summary</div>
      <div class="small-muted">
        <xsl:text>Version </xsl:text>
        <xsl:choose>
          <xsl:when test="@Version">
            <xsl:value-of select="@Version"/>
          </xsl:when>
          <xsl:otherwise>—</xsl:otherwise>
        </xsl:choose>
        <xsl:text> — DefaultVernWs: </xsl:text>
        <xsl:choose>
          <xsl:when test="@DefaultVernWs">
            <xsl:value-of select="@DefaultVernWs"/>
          </xsl:when>
          <xsl:otherwise>—</xsl:otherwise>
        </xsl:choose>
      </div>

      <!-- Process phoneme sets -->
      <xsl:apply-templates select=".//PhPhonemeSet"/>

      <!-- Natural classes -->
      <xsl:if test=".//PhNCSegments">
        <div class="section-title">Natural Classes</div>
        <xsl:apply-templates select=".//PhNCSegments"/>
      </xsl:if>

      <!-- Environments -->
      <xsl:if test=".//Environments">
        <xsl:apply-templates select=".//Environments"/>
      </xsl:if>
    </div>
  </xsl:template>

  <!-- Template for PhonemeSet -->
  <xsl:template match="PhPhonemeSet">
    <div class="natclass">
      <div class="section-title">
        <xsl:call-template name="get-auni-text">
          <xsl:with-param name="node" select="Name"/>
          <xsl:with-param name="default">Phoneme Set</xsl:with-param>
        </xsl:call-template>
      </div>
      
      <xsl:if test="Description/Run">
        <div class="small-muted">
          <xsl:value-of select="Description/Run"/>
        </div>
      </xsl:if>

      <!-- Phoneme table -->
      <table class="phonemes">
        <thead>
          <tr>
            <th>Symbol</th>
            <th>Description</th>
            <th>ID</th>
            <th>Codes</th>
          </tr>
        </thead>
        <tbody>
          <xsl:apply-templates select=".//PhPhoneme"/>
        </tbody>
      </table>

      <!-- Boundary markers -->
      <xsl:if test=".//PhBdryMarker">
        <div class="section-title">Boundary Markers</div>
        <div class="small-muted">
          <xsl:apply-templates select=".//PhBdryMarker" mode="boundary"/>
        </div>
      </xsl:if>
    </div>
  </xsl:template>

  <!-- Template for PhPhoneme -->
  <xsl:template match="PhPhoneme">
    <tr>
      <xsl:attribute name="id">
        <xsl:text>phoneme-row-</xsl:text>
        <xsl:value-of select="@Id"/>
      </xsl:attribute>
      
      <td>
        <span class="symbol-pill" style="cursor: pointer">
          <xsl:call-template name="get-auni-text">
            <xsl:with-param name="node" select="Name"/>
            <xsl:with-param name="default">(no symbol)</xsl:with-param>
          </xsl:call-template>
        </span>
      </td>
      <td>
        <xsl:value-of select="Description/Run"/>
      </td>
      <td>
        <xsl:value-of select="@Id"/>
      </td>
      <td>
        <xsl:for-each select="Codes/PhCode/Representation/AUni">
          <xsl:if test="position() &gt; 1">, </xsl:if>
          <xsl:value-of select="normalize-space(.)"/>
        </xsl:for-each>
      </td>
    </tr>
  </xsl:template>

  <!-- Template for boundary markers -->
  <xsl:template match="PhBdryMarker" mode="boundary">
    <div>
      <xsl:call-template name="get-auni-text">
        <xsl:with-param name="node" select="Name"/>
        <xsl:with-param name="default">
          <xsl:value-of select="@Id"/>
        </xsl:with-param>
      </xsl:call-template>
      
      <xsl:if test="Codes/PhCode/Representation/AUni">
        <xsl:text> (</xsl:text>
        <xsl:for-each select="Codes/PhCode/Representation/AUni">
          <xsl:if test="position() &gt; 1">, </xsl:if>
          <xsl:value-of select="normalize-space(.)"/>
        </xsl:for-each>
        <xsl:text>)</xsl:text>
      </xsl:if>
    </div>
  </xsl:template>

  <!-- Template for Natural Classes -->
  <xsl:template match="PhNCSegments">
    <div class="natclass">
      <xsl:attribute name="id">
        <xsl:text>natclass-</xsl:text>
        <xsl:value-of select="@Id"/>
      </xsl:attribute>
      
      <div class="section-title">
        <xsl:call-template name="get-auni-text">
          <xsl:with-param name="node" select="Name"/>
          <xsl:with-param name="default">Unnamed</xsl:with-param>
        </xsl:call-template>
        
        <xsl:variable name="abbr">
          <xsl:call-template name="get-auni-text">
            <xsl:with-param name="node" select="Abbreviation"/>
          </xsl:call-template>
        </xsl:variable>
        
        <xsl:if test="string-length($abbr) &gt; 0">
          <xsl:text> (</xsl:text>
          <xsl:value-of select="$abbr"/>
          <xsl:text>)</xsl:text>
        </xsl:if>
      </div>
      
      <xsl:if test="Description/Run">
        <div class="small-muted">
          <xsl:value-of select="Description/Run"/>
        </div>
      </xsl:if>
      
      <div class="members">
        <xsl:for-each select="Segments">
          <span class="symbol-pill" style="cursor: pointer">
            <xsl:attribute name="data-phoneme-id">
              <xsl:value-of select="@dst"/>
            </xsl:attribute>
            <xsl:value-of select="@dst"/>
          </span>
          <xsl:text> </xsl:text>
        </xsl:for-each>
      </div>
    </div>
  </xsl:template>

  <!-- Template for Environments -->
  <xsl:template match="Environments">
    <div class="natclass">
      <div class="section-title">Environments</div>
      <div class="small-muted">
        <xsl:choose>
          <xsl:when test="*">
            <xsl:apply-templates mode="generic"/>
          </xsl:when>
          <xsl:otherwise>(no environment definitions)</xsl:otherwise>
        </xsl:choose>
      </div>
    </div>
  </xsl:template>

  <!-- Generic mode for nested elements -->
  <xsl:template match="*" mode="generic">
    <div>
      <xsl:value-of select="local-name()"/>
      <xsl:if test="*">
        <xsl:apply-templates mode="generic"/>
      </xsl:if>
    </div>
  </xsl:template>

  <!-- Helper template to extract AUni text -->
  <xsl:template name="get-auni-text">
    <xsl:param name="node"/>
    <xsl:param name="default" select="''"/>
    
    <xsl:choose>
      <xsl:when test="$node/AUni">
        <xsl:value-of select="normalize-space($node/AUni[1])"/>
      </xsl:when>
      <xsl:when test="$node">
        <xsl:value-of select="normalize-space($node)"/>
      </xsl:when>
      <xsl:otherwise>
        <xsl:value-of select="$default"/>
      </xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
