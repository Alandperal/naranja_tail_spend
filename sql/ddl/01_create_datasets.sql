-- =============================================================================
-- FILE: 01_create_datasets.sql
-- PROJECT: Tail Spend Analytics — Procurement Intelligence Platform
-- LAYER: Infrastructure / Dataset Provisioning
-- AUTHOR: Analytics Engineering Team
-- UPDATED: 2026-03-30
-- =============================================================================
-- DESCRIPTION:
--   Creates the four logical dataset layers used throughout the solution:
--     1. raw_procurement   → canonical source tables (as-is schema from CSVs)
--     2. stg_procurement   → standardized, typed, parsed staging tables
--     3. mart_procurement  → analytics-ready dimensional/fact tables
--     4. audit_procurement → compliance and anomaly detection outputs
-- =============================================================================

-- ─────────────────────────────────────────────────────────────────────────────
-- LAYER 1: Raw / Source Layer
-- Preserves the business source schema exactly as defined in the spec.
-- No transformations are applied here. Locale-formatted strings stored as-is.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE SCHEMA IF NOT EXISTS `naranja-x-491820.raw_procurement`
OPTIONS (
  description = "Canonical source layer — preserves original CSV schema verbatim. No parsing applied.",
  location     = "US"
);

-- ─────────────────────────────────────────────────────────────────────────────
-- LAYER 2: Staging Layer
-- Responsible for: locale normalization, type casting, null handling,
-- deduplication, date parsing, and referential integrity validation.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE SCHEMA IF NOT EXISTS `naranja-x-491820.stg_procurement`
OPTIONS (
  description = "Staging layer — parsed, typed, deduplicated. One-to-one with raw tables plus derived helper columns.",
  location     = "US"
);

-- ─────────────────────────────────────────────────────────────────────────────
-- LAYER 3: Analytics Mart Layer
-- Star/snowflake schema optimized for Looker explores and CFO-level reporting.
-- Contains fact tables, dimension tables, and pre-aggregated summary marts.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE SCHEMA IF NOT EXISTS `naranja-x-491820.mart_procurement`
OPTIONS (
  description = "Analytics mart layer — dimensional model, homogeneous currency, KPI marts, sourcing strategy outputs.",
  location     = "US"
);

-- ─────────────────────────────────────────────────────────────────────────────
-- LAYER 4: Audit / Compliance Layer
-- Contains anomaly detection outputs: split-purchase alerts,
-- concentration scores, favoritism indicators, and audit trail tables.
-- ─────────────────────────────────────────────────────────────────────────────
CREATE SCHEMA IF NOT EXISTS `naranja-x-491820.audit_procurement`
OPTIONS (
  description = "Audit and compliance layer — split-purchase alerts, HHI concentration, favoritism indicators.",
  location     = "US"
);
