<?xml version="1.0" encoding="ISO-8859-1"?>
<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
<xsl:output method="xml" encoding="ISO-8859-1" indent="yes" doctype-system="nag.dtd"/>

<xsl:template match="/">
    <xsl:apply-templates/>
</xsl:template>

<xsl:template match="*">
        <xsl:element name="{name()}">
                <xsl:apply-templates select="@*"/>
                <xsl:apply-templates/>
        </xsl:element>
</xsl:template>

<xsl:template match="@*">
        <xsl:copy/>
</xsl:template>

<xsl:template match="text()"/>

</xsl:stylesheet>
