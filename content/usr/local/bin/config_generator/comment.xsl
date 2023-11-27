<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform" xmlns:xalan="http://xml.apache.org/xslt">
<xsl:output method="xml" encoding="UTF-8" indent="yes" xalan:indent-amount="4" doctype-system="nag.dtd"/>

<xsl:template match="/">
    <xsl:apply-templates/>
</xsl:template>

<xsl:template match="*">
        <xsl:element name="{name()}">
                <xsl:apply-templates select="@*"/>
                <xsl:if test="name() = 'host' and parent::host">
                        <xsl:comment><xsl:text> parent: </xsl:text><xsl:value-of select="parent::host/@id"/>
                        <xsl:text> </xsl:text>
                        </xsl:comment>
                        <xsl:apply-templates select="." mode="find_group" />
                </xsl:if>
                <xsl:apply-templates/>
        </xsl:element>

        <xsl:if test="child::host">
        <xsl:comment>
                <xsl:text> </xsl:text><xsl:value-of select="name(.)"/>
                <xsl:text>, </xsl:text>
                <xsl:apply-templates select="@*" mode="comment"/>
        </xsl:comment>
        </xsl:if>
</xsl:template>

<xsl:template match="@*">
        <xsl:copy/>
</xsl:template>

<xsl:template match="host" mode="find_group">
        <xsl:choose>
                <xsl:when test='@hostgroup'>
                        <xsl:comment><xsl:text> hostgroup: </xsl:text><xsl:value-of select="@hostgroup"/><xsl:text> </xsl:text></xsl:comment>
                </xsl:when>
                <xsl:otherwise>
                        <xsl:apply-templates select="parent::host" mode="find_group"/>
                </xsl:otherwise>
        </xsl:choose>
</xsl:template>

<xsl:template match="@*" mode="comment">
        <xsl:value-of select="name(.)"/>
        <xsl:text>=</xsl:text>
        <xsl:value-of select="."/><xsl:text> </xsl:text>
</xsl:template>

</xsl:stylesheet>
