<?xml version="1.0" encoding="UTF-8"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="html" encoding="UTF-8" indent="yes"/>
  
  <!-- Parameter for view mode: 'card' or 'table' -->
  <xsl:param name="viewMode" select="'card'"/>
  
  <!-- Parameter for visible gloss languages (comma-separated) -->
  <xsl:param name="glossLangs" select="''"/>

  <!-- Root template -->
  <xsl:template match="/">
    <div>
      <div class="section-title">Wordforms</div>
      
      <!-- Controls row placeholder (managed by JavaScript) -->
      <div class="controls-inline"></div>
      
      <!-- Search row placeholder (managed by JavaScript) -->
      <div class="small-muted" style="margin-top: 8px">
        Filter: <input id="wf_search" placeholder="search form or gloss..." style="padding:4px;border-radius:4px;border:1px solid #ddd;margin-left:6px;"/>
      </div>
      
      <!-- List area -->
      <div style="margin-top: 8px">
        <xsl:choose>
          <xsl:when test="$viewMode = 'card'">
            <xsl:apply-templates select=".//wordform | .//WordForm | .//Wordform" mode="card"/>
          </xsl:when>
          <xsl:otherwise>
            <xsl:call-template name="render-table"/>
          </xsl:otherwise>
        </xsl:choose>
      </div>
    </div>
  </xsl:template>

  <!-- Card view template -->
  <xsl:template match="wordform | WordForm | Wordform" mode="card">
    <div class="wordform-card">
      <div class="wordform-header">
        <div>
          <div class="wordform-main">
            <xsl:call-template name="get-form-text"/>
          </div>
          <div class="wordform-meta">
            <xsl:text>Predicted: </xsl:text>
            <xsl:value-of select="@PredictedAnalyses | @predictedanalyses | PredictedAnalyses"/>
            <xsl:text> · User: </xsl:text>
            <xsl:value-of select="@UserAnalyses | @useranalyses | UserAnalyses"/>
          </div>
        </div>
        <button class="small-btn" title="Toggle details">▾</button>
      </div>
      
      <div class="wordform-body" style="display: block">
        <xsl:choose>
          <xsl:when test="analysis | Analysis">
            <xsl:apply-templates select="analysis | Analysis" mode="card-analysis"/>
          </xsl:when>
          <xsl:otherwise>
            <div class="small-muted">— No analysis —</div>
          </xsl:otherwise>
        </xsl:choose>
      </div>
    </div>
  </xsl:template>

  <!-- Analysis in card mode -->
  <xsl:template match="analysis | Analysis" mode="card-analysis">
    <xsl:if test="gloss | Gloss">
      <xsl:for-each select="gloss | Gloss">
        <div>
          <strong>
            <xsl:text>Gloss (</xsl:text>
            <xsl:choose>
              <xsl:when test="@ws">
                <xsl:value-of select="@ws"/>
              </xsl:when>
              <xsl:when test="AUni/@ws">
                <xsl:value-of select="AUni/@ws"/>
              </xsl:when>
              <xsl:otherwise>—</xsl:otherwise>
            </xsl:choose>
            <xsl:text>):</xsl:text>
          </strong>
          <xsl:text> </xsl:text>
          <xsl:choose>
            <xsl:when test="AUni">
              <xsl:value-of select="normalize-space(AUni)"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="normalize-space(.)"/>
            </xsl:otherwise>
          </xsl:choose>
        </div>
      </xsl:for-each>
    </xsl:if>
    
    <xsl:if test="category | Category">
      <div>
        <xsl:text>Category: </xsl:text>
        <xsl:value-of select="normalize-space(category | Category)"/>
      </div>
    </xsl:if>
  </xsl:template>

  <!-- Table view template -->
  <xsl:template name="render-table">
    <table class="wordforms-table" style="border-collapse: collapse; width: 100%; margin-top: 8px;">
      <thead>
        <tr style="background: #f5f5f5; border-bottom: 2px solid #ddd;">
          <th style="padding: 8px; text-align: left; border: 1px solid #ddd;">Form</th>
          <th style="padding: 8px; text-align: left; border: 1px solid #ddd;">Gloss</th>
          <th style="padding: 8px; text-align: left; border: 1px solid #ddd;">Category</th>
          <th style="padding: 8px; text-align: center; border: 1px solid #ddd;">Predicted</th>
          <th style="padding: 8px; text-align: center; border: 1px solid #ddd;">User</th>
        </tr>
      </thead>
      <tbody>
        <xsl:apply-templates select=".//wordform | .//WordForm | .//Wordform" mode="table"/>
      </tbody>
    </table>
  </xsl:template>

  <!-- Table row template -->
  <xsl:template match="wordform | WordForm | Wordform" mode="table">
    <tr style="border-bottom: 1px solid #eee;">
      <td style="padding: 8px; border: 1px solid #ddd;">
        <xsl:call-template name="get-form-text"/>
      </td>
      <td style="padding: 8px; border: 1px solid #ddd;">
        <xsl:for-each select=".//gloss | .//Gloss">
          <xsl:if test="position() &gt; 1">; </xsl:if>
          <xsl:choose>
            <xsl:when test="AUni">
              <xsl:value-of select="normalize-space(AUni)"/>
            </xsl:when>
            <xsl:otherwise>
              <xsl:value-of select="normalize-space(.)"/>
            </xsl:otherwise>
          </xsl:choose>
        </xsl:for-each>
      </td>
      <td style="padding: 8px; border: 1px solid #ddd;">
        <xsl:for-each select=".//category | .//Category">
          <xsl:if test="position() &gt; 1">; </xsl:if>
          <xsl:value-of select="normalize-space(.)"/>
        </xsl:for-each>
      </td>
      <td style="padding: 8px; text-align: center; border: 1px solid #ddd;">
        <xsl:value-of select="@PredictedAnalyses | @predictedanalyses | PredictedAnalyses"/>
      </td>
      <td style="padding: 8px; text-align: center; border: 1px solid #ddd;">
        <xsl:value-of select="@UserAnalyses | @useranalyses | UserAnalyses"/>
      </td>
    </tr>
  </xsl:template>

  <!-- Helper template to get form text -->
  <xsl:template name="get-form-text">
    <xsl:choose>
      <xsl:when test="form/AUni | Form/AUni">
        <xsl:value-of select="normalize-space((form/AUni | Form/AUni)[1])"/>
      </xsl:when>
      <xsl:when test="form | Form">
        <xsl:value-of select="normalize-space((form | Form)[1])"/>
      </xsl:when>
      <xsl:when test="word | Word">
        <xsl:value-of select="normalize-space((word | Word)[1])"/>
      </xsl:when>
      <xsl:otherwise>(no form)</xsl:otherwise>
    </xsl:choose>
  </xsl:template>

</xsl:stylesheet>
