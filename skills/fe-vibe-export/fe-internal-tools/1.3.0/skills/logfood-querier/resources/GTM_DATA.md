# GTM Data Schema Documentation

## Overview
The `main.gtm_data` schema contains 275 tables that support Go-To-Market (GTM) analytics, sales operations, customer success, and strategic planning at Databricks. This comprehensive data warehouse integrates data from Salesforce, Workday, consumption systems, third-party enrichment providers, and internal operational systems.

**Schema:** `main.gtm_data`
**Total Tables:** 275
**Last Updated:** 2025-10-28

---

## Table Categories

### 1. Core Account & Customer Data

These tables contain foundational customer and account information from Salesforce, enriched with internal metrics and hierarchies.

#### Key Tables:
- **`core_accounts_curated`** - Master account table with 229 columns including account details, sales hierarchies, ARR, consumption metrics, customer lifecycle stages, and strategic attributes
- **`account_activated_customers`** - Tracking for activated customer accounts
- **`activated_customers_gold`** - Gold-standard activated customer data
- **`1k_customers_gold`** - Top 1000 customers by importance
- **`account_arr_details`** - Account-level ARR breakdown and details
- **`account_rankings`** - Account ranking metrics across different dimensions
- **`ds_account_gold`** - Data science enriched account data
- **`account_industry`** - Industry classification and vertical mapping
- **`account_competitor_mapping`** - Competitor presence by account

#### Data Contains:
- Account identification (Salesforce IDs, names, parent hierarchies)
- Customer classification (type, status, segment, tier)
- Sales organization (AE, manager, leader, SA, DSA hierarchies)
- Geographic organization (region, subregion levels 1-4)
- Financial metrics (ARR, MRR, T3M annualized consumption)
- Customer lifecycle (start dates, renewal dates, customer age)
- Strategic flags (Fortune 500, top accounts, partner types)
- Industry and vertical classifications
- Support and success tiers
- Multi-cloud indicators and cloud platform details

#### Example Questions:
- What is the total ARR by sales region and account segment?
- Which Fortune 500 accounts have upcoming renewals in Q2?
- What is the distribution of activated customers by industry vertical?
- Which accounts have multi-cloud deployments?
- What are the top 100 accounts by T3M consumption globally?
- Which accounts are flagged as strategic but have declining consumption?

---

### 2. Opportunity & Pipeline Management

Tables tracking sales opportunities, pipeline stages, forecasting, and deal progression.

#### Key Tables:
- **`core_opportunity_curated`** - Master opportunity table with 213 columns including deal details, stages, amounts, product mix, and forecasting
- **`core_opportunity_product`** - Product-level details for opportunities
- **`opportunity_product_attach_details`** - Product attachment analysis
- **`e2e_opportunity_mapping_table`** - End-to-end opportunity lifecycle mapping
- **`pipe_coverage_new`** - Pipeline coverage analysis
- **`pipe_gen_results`** - Pipeline generation results and tracking
- **`pipe_hyg_status`** - Pipeline hygiene status tracking
- **`tofu_pipe_gen`** - Top-of-funnel pipeline generation

#### Data Contains:
- Opportunity identification and ownership
- Deal stages and progression (prospecting, POC, evaluation, negotiation)
- Financial details (amount, commit amounts, subscription totals, ARR impact)
- Product breakdown (commit, support, license, services, usage)
- Pipeline metrics (probability, forecast category, stage timestamps)
- Deal characteristics (type: new business/upsell/renewal, platform, sales play)
- Loss/churn tracking (reasons, outcomes, mitigation plans)
- Partner involvement and marketplace deals
- Campaign source and lead attribution

#### Example Questions:
- What is the total pipeline value by stage and region for Q4?
- Which opportunities moved from evaluation to negotiation this month?
- What is the average time-to-close by opportunity type?
- Which lost opportunities cited competitor X as the reason?
- What is the pipeline coverage ratio by sales rep?
- Which deals have AWS marketplace involvement?
- What is the product mix distribution across current pipeline?

---

### 3. Consumption & Usage Analytics (C360)

Customer 360 tables providing detailed consumption, usage, and behavioral metrics.

#### Key Tables:
- **`c360_consumption_monthly`** - Monthly consumption metrics by account, workspace, SKU with 61 columns including DBU breakdowns by product (GenAI, SQL, ML, Delta, UC)
- **`c360_consumption_daily`** - Daily consumption tracking
- **`c360_consumption_weekly`** - Weekly consumption aggregates
- **`c360_consumption_quarterly`** - Quarterly consumption rollups
- **`c360_consumption_account_monthly`** - Account-level monthly consumption
- **`c360_consumption_runrate`** - Consumption run-rate projections
- **`core_consumption_daily`** - Core daily consumption data
- **`core_account_consumption_measures_daily`** - Daily account consumption measures
- **`core_account_consumption_measures_monthly`** - Monthly account consumption measures
- **`c360_active_users_monthly`** - Monthly active user counts
- **`login_active_users`** - Login-based active user tracking
- **`c360_base_metric_summary`** - Summary of base C360 metrics

#### Data Contains:
- DBU consumption (total, by product: GenAI, SQL, Delta, UC, ML)
- Dollar consumption (actual, list price, pre-royalty)
- Product-specific metrics (serverless, photon, DLT, Fivetran, dbt)
- GenAI consumption breakdown (MCT, non-MCT, foundation models, vector search)
- Workspace-level details (workspace ID, name, platform, cloud)
- SKU-level consumption tracking
- Sales hierarchy alignment (AE, SA, DSA, manager, leader)
- Organic growth baselines and pipeline-weighted forecasts
- Active users and login metrics

#### Example Questions:
- What is the MoM growth rate for GenAI consumption by account?
- Which accounts have serverless SQL adoption above 50%?
- What is the total Unity Catalog consumption trend over the last 6 months?
- Which workspaces show declining DBU consumption?
- What is the photon adoption rate by industry vertical?
- Which accounts have the highest Delta Lake to total consumption ratio?
- What is the average consumption per active user by account tier?

---

### 4. Use Case Tracking & Pipeline

Tables for tracking customer use case implementation, adoption, and pipeline.

#### Key Tables:
- **`core_usecase_curated`** - Master use case table with 263 columns tracking implementation stages, estimated value, blockers, and ownership
- **`core_usecase`** - Core use case data
- **`core_usecase_conversion`** - Use case conversion metrics
- **`core_usecase_pipeline_projections`** - Use case pipeline forecasting
- **`e2e_usecase_mapping_table`** - End-to-end use case lifecycle mapping
- **`usecase_pipe_gen_amount`** - Use case pipeline generation amounts
- **`use_case_tshirt_sizing_list`** - T-shirt sizing for use cases
- **`tofu_use_case_detail_with_sf_hierarchy`** - Top-of-funnel use case details

#### Data Contains:
- Use case identification and naming
- Implementation stages (validating, scoping, evaluating, confirming, onboarding, live, lost)
- Estimated monthly/quarterly DBU and dollar value
- Product breakdowns (GenAI, DBSQL allocation percentages)
- Workspace association and status
- Blocker tracking (number, descriptions, last modified)
- Migration details (type, source platform, competitor info)
- Timeline tracking (target dates, actual dates, days in stage)
- Professional services project linkage
- Partner involvement and implementation status
- XDR/SDR sourcing and qualification notes

#### Example Questions:
- How many use cases are in the onboarding stage by region?
- What is the average time from validating to live by use case type?
- Which use cases have blockers that haven't been updated in 30+ days?
- What is the total estimated monthly value of use cases in the pipeline?
- Which accounts have the most use cases in evaluation stage?
- What are the top blocker types preventing use case progression?
- Which migration use cases target Snowflake as the source platform?

---

### 5. Commit & Contract Management

Tables tracking customer commits, contracts, and consumption against commitments.

#### Key Tables:
- **`core_commit_measures`** - Comprehensive commit tracking with 90 columns including burn-down, forecasting, and renewal details
- **`core_contract_details`** - Contract-level details and relationships
- **`core_cpq_commit_measures`** - CPQ commit tracking
- **`core_cpq_commit_measures_monthly`** - Monthly CPQ commit measures
- **`core_aggorder_commit_measures`** - Aggregated order commit metrics
- **`commit_clari_forecast_gold`** - Clari-sourced commit forecasts
- **`commit_clari_forecast_daily_history`** - Historical daily commit forecasts

#### Data Contains:
- Contract identification (contract ID, number, subscription IDs)
- Contract lifecycle (start/end dates, term length, status, rank)
- Commit amounts (total, customer portion, revshare, complimentary)
- Contract types (first commit, parallel, master contract indicators)
- Consumption tracking (consumed/remaining DBUs, burn-down percentage)
- Forecast data (DS forecasts, SL forecasts, burst predictions)
- Renewal tracking (renewal dates, outcomes, extensions, late days)
- TCV and ARR calculations (total contract value, annualized metrics)
- Contract relationships (previous, follow-on contract IDs)

#### Example Questions:
- Which commits are forecasted to burst in the next 90 days?
- What is the average burn-down percentage across all active commits?
- Which accounts have commits with lagging burn-down?
- What is the total remaining commit value by renewal quarter?
- Which contracts have been extended and why?
- What is the forecast accuracy for commit consumption (DS vs actuals)?
- Which accounts have parallel or master contracts?

---

### 6. Forecasting & Targets

Tables containing forecasts from various sources and target tracking.

#### Key Tables:
- **`core_forecasts_by_period`** - Period-based forecast aggregations
- **`core_individual_sales_forecast`** - Individual sales rep forecasts
- **`core_account_sales_forecast`** - Account-level sales forecasts
- **`core_individual_ds_forecasts`** - Data science individual forecasts
- **`core_commit_ds_forecast`** - Data science commit forecasts
- **`ae_forecasts`** - Account executive submitted forecasts
- **`finance_forecast_gold`** - Finance-approved forecasts
- **`finance_only_forecast_gold`** - Finance-only forecast data
- **`best_case_forecast_gold`** - Best-case scenario forecasts
- **`fcst_land_expand_gold`** - Land and expand forecast model
- **`headcount_forecast_gold`** - Headcount forecasting
- **`core_account_targets`** - Account-level targets
- **`core_bu_targets`** - Business unit targets
- **`combined_targets`** - Consolidated target data
- **`manager_ae_targets_gold`** - Manager and AE target assignments

#### Data Contains:
- Forecast submissions (multiple forecast categories: commit, most likely, best case)
- Temporal breakdowns (fiscal year, quarter, month)
- Hierarchical rollups (individual → manager → leader → BU)
- Forecast types (sales, consumption, commit, headcount)
- Target assignments (quotas, goals by period)
- Forecast accuracy tracking
- Land and expand projections

#### Example Questions:
- What is the forecast variance between AE submissions and finance forecasts?
- Which managers are forecasting above/below their targets?
- What is the forecast vs actuals comparison for last quarter?
- Which business units have the highest target attainment?
- What is the best case vs most likely forecast spread by region?
- How have individual forecasts changed week-over-week?
- What is the headcount forecast compared to actual hiring?

---

### 7. Professional Services

Tables tracking professional services projects, resources, billing, and delivery.

#### Key Tables:
- **`core_professional_services_dim_project`** - Project dimension table
- **`core_professional_services_assignments`** - Resource assignments to projects
- **`core_professional_services_bookings`** - PS bookings data
- **`core_professional_services_bookings_forecast`** - PS bookings forecast
- **`core_professional_services_billing_events`** - Billing event tracking
- **`core_professional_services_billing_report`** - Billing reports
- **`core_professional_services_billed_revenue`** - Billed revenue tracking
- **`core_professional_services_delivered_revenue`** - Delivered revenue recognition
- **`core_professional_services_delivered_revenue_metrics`** - Delivered revenue KPIs
- **`core_professional_services_resource_utilization`** - Resource utilization metrics
- **`core_professional_services_resource_bif_utilization`** - BIF utilization
- **`core_professional_services_timecards`** - Timecard tracking
- **`core_professional_services_milestones`** - Project milestones
- **`core_professional_services_project_tasks`** - Task-level tracking
- **`core_professional_services_backlog_metrics`** - Backlog KPIs
- **`core_professional_services_survey`** - Customer satisfaction surveys
- **`core_professional_services_survey_metrics`** - Survey metrics and CSAT scores

#### Data Contains:
- Project details (IDs, names, status, type, dates)
- Resource allocation and utilization
- Time tracking (hours logged, billable vs non-billable)
- Financial metrics (bookings, revenue, billing, backlog)
- Project health (status, milestones, tasks)
- Customer satisfaction (survey scores, feedback)
- Delivery metrics (QTD, QTG comparisons)

#### Example Questions:
- What is the average resource utilization rate across all consultants?
- Which projects have the highest backlog?
- What is the monthly delivered revenue trend for professional services?
- Which projects have missed milestone dates?
- What is the average CSAT score by project type?
- How many billable hours were logged last quarter by region?
- Which resources are below target utilization?

---

### 8. Customer Success & Support

Tables for tracking customer health, support cases, escalations, and success metrics.

#### Key Tables:
- **`support_cases_gold`** - Master support case table with 65 columns including case details, resolution tracking, SLA metrics, and satisfaction scores
- **`sfdc_support_case`** - Raw Salesforce support case data
- **`sfdc_cases_silver`** - Silver-tier case data
- **`sfdc_escalation_object_silver`** - Escalation tracking
- **`sfdc_surveys_silver`** - Support satisfaction surveys
- **`core_customer_success_onboarding_metrics`** - CS onboarding tracking
- **`core_success_credits`** - Success credits and entitlements
- **`uco_health_score`** - Use case health scores
- **`uco_health_score_daily`** - Daily health score tracking
- **`gtm_health_scorecard`** - Overall GTM health metrics
- **`incident_management_by_account`** - Account-level incident tracking
- **`core_incident_account_region_details`** - Incident details by region

#### Data Contains:
- Case tracking (case number, subject, status, priority, component)
- Timestamps (opened, closed, resolution time)
- Case ownership and assignment
- Support tier and account association
- SLA achievement (FDR, FWR, response time metrics)
- Escalation details (backline escalations, reasons, severity)
- Customer satisfaction (NSAT, CES scores, survey comments)
- Feature request tracking
- Workspace and cloud platform association

#### Example Questions:
- What is the average time-to-resolution by case priority?
- Which accounts have the most open P1 cases?
- What is the NSAT score trend over the last 6 months?
- Which components generate the most support cases?
- What percentage of cases met SLA requirements last quarter?
- Which accounts have recent backline escalations?
- What are the most common case resolution types?
- Which support engineers have the highest case closure rates?

---

### 9. Third-Party Enrichment Data

External data sources providing market intelligence, funding data, and technology insights.

#### Key Tables:

**Crunchbase Data:**
- **`crunchbase_organizations`** - Company information with 150 columns including funding, valuation, employee counts, and market data
- **`crunchbase_funding_rounds`** - Funding round details
- **`crunchbase_investments`** - Investment tracking
- **`crunchbase_acquisitions`** - M&A activity
- **`crunchbase_people`** - Executive and founder information
- **`crunchbase_locations`** - Geographic location data
- **`crunchbase_categories`** - Industry categorization

**HGI (Intricately) Data:**
- **`hgi_v2_spend`** - Cloud spend estimates
- **`hgi_v2_contract`** - Technology contract data
- **`hgi_v2_installs`** - Technology installation tracking
- **`hgi_databricks_matching`** - Databricks installation matching
- **`hgi_v2_relative_spend`** - Relative spend comparisons

**Sumble Data:**
- **`sumble_accounts_enriched`** - Enriched account technology data
- **`sumble_trends`** - Technology adoption trends
- **`sumble_accounts_recent_projects`** - Recent project activity
- **`sumble_organizations_trend`** - Organization-level trends

**Other Sources:**
- **`pitchbook_new_data`** - Pitchbook market data
- **`funding_and_employment_data`** - Employment and funding metrics
- **`zi_intent_data`** - 6sense intent data

#### Data Contains:
- Company profiles (founding dates, descriptions, status)
- Funding information (rounds, amounts, investors, valuations)
- Employee counts and growth trends
- Technology stack and cloud spend
- Competitive intelligence
- Intent signals and buying stage
- Market rankings and trends

#### Example Questions:
- Which prospects recently raised Series B funding?
- What is the cloud spend distribution for target accounts?
- Which accounts show high intent for data platform solutions?
- Which companies have competing technologies installed?
- What is the average employee growth rate for our target segment?
- Which accounts have recent M&A activity?
- What is the correlation between funding stage and Databricks ARR?

---

### 10. Organic Growth & Projections

Tables for baseline growth analysis and pipeline-based projections.

#### Key Tables:
- **`core_organic_growth_baseline_monthly`** - Monthly organic growth baselines
- **`core_organic_growth_baseline_quarterly`** - Quarterly organic growth baselines
- **`core_organic_growth_with_pipeline`** - Organic growth combined with pipeline
- **`organic_growth_rates_fy26`** - FY26 growth rate targets
- **`tofu_og_and_oucp_account_level_with_hierarchy`** - Account-level OG/OUCP metrics
- **`og_master_account_daily`** - Daily organic growth tracking

#### Data Contains:
- Baseline consumption projections
- Growth rate assumptions
- Pipeline-weighted growth projections
- Account-level growth trends
- Product-specific growth baselines (SQL, UC, GenAI)

#### Example Questions:
- What is the organic growth baseline for Q3 by region?
- Which accounts exceed their organic growth projections?
- What is the expected growth contribution from GenAI products?
- How does pipeline coverage affect growth projections?
- Which accounts have negative organic growth trends?

---

### 11. Sales Territories & Hierarchies

Reference tables for organizational structure and user hierarchies.

#### Key Tables:
- **`ref_account_upstream_and_direct_hierarchy`** - Account ownership hierarchy
- **`ref_account_upstream_and_direct_hierarchy_rls`** - RLS-enabled account hierarchy
- **`ref_individual_upstream_and_direct_hierarchy`** - Individual user hierarchy
- **`ref_individual_upstream_and_direct_hierarchy_rls`** - RLS-enabled user hierarchy
- **`ref_sfdc_wd_upstream_and_direct_user_hierarchy`** - Salesforce + Workday user hierarchy
- **`sf_user_with_hierarchy`** - Salesforce users with hierarchy
- **`active_account_executives`** - Current active AEs
- **`workday_field_hierarchy`** - Workday organizational structure

#### Data Contains:
- User identification and roles
- Reporting relationships (manager, leader chains)
- Territory assignments
- Cost center and department mappings
- Active/inactive status
- Business unit alignment

#### Example Questions:
- Who reports up to a specific VP?
- Which AEs are in the EMEA commercial segment?
- What is the full reporting chain for a given user?
- Which territories have recent AE turnover?

---

### 12. GTM OKRs & Metrics

Strategic objective and key result tracking.

#### Key Tables:
- **`gtm_okrs_fy25`** - FY25 GTM OKRs with 19 columns tracking priorities, actuals vs targets, and attainment
- **`gtm_okr_fy25__trr_new_customers__dashboard_detail`** - TRR new customer OKR details
- **`gtm_okr_fy25__trr_new_customers__detail`** - TRR new customer drill-down
- **`feokrs_fy24_summary_table`** - FY24 field engineering OKRs
- **`gtm_ae_productivity`** - AE productivity metrics
- **`g2k_review_list`** - Global 2000 account reviews

#### Data Contains:
- OKR definitions and ownership
- Actuals vs targets by period
- Attainment percentages
- Regional and segment breakdowns
- Forecast vs target comparisons

#### Example Questions:
- What is the Q2 attainment across all GTM OKRs?
- Which regions are above/below OKR targets?
- What is the trend in new customer TRR OKR?
- Which OKRs are at risk of missing targets?
- What is the correlation between AE productivity and quota attainment?

---

### 13. Product & SKU Data

Product definitions, pricing, and availability.

#### Key Tables:
- **`dim_products`** - Product dimension table
- **`products_availability`** - Product availability by region/cloud
- **`product_adoption_metrics`** - Product adoption tracking
- **`product_last_30_day_measures`** - Recent product usage metrics
- **`professional_services_product_mappings`** - PS to product mappings

#### Data Contains:
- Product names and SKU codes
- Product categories and families
- Pricing information
- Cloud/region availability
- Adoption rates and metrics

#### Example Questions:
- Which products have the highest adoption rates?
- What is the pricing for Photon by cloud provider?
- Which products are available on GCP?
- What is the product mix across the customer base?

---

### 14. Meetings & Activities

Activity tracking and meeting classification.

#### Key Tables:
- **`silver_external_meetings_by_user`** - External meeting tracking
- **`meetings_classification_dim`** - Meeting type classifications
- **`chief_ai_officer_meetings`** - Executive-level meeting tracking
- **`activity_tracker_pipeline`** - Activity pipeline tracking

#### Data Contains:
- Meeting dates and durations
- Meeting participants and organizers
- Meeting classifications (external, internal, prospect, customer)
- Activity metrics

#### Example Questions:
- How many customer meetings did each AE have last month?
- Which accounts had no engagement activity in 90 days?
- What is the average meeting volume by role?
- Which prospects have C-level meeting engagement?

---

### 15. Partner & Channel Data

Partner relationships, co-sell tracking, and marketplace deals.

#### Key Tables:
- **`account_competitor_mapping`** - Partner and competitor presence
- **`sap_target_accounts`** - SAP partnership target accounts
- **`sap_customer_matching`** - SAP customer matching
- **`azure_commercial_accounts`** - Azure marketplace accounts

#### Data Contains:
- Partner types and categories
- Co-sell opportunities
- Marketplace deal tracking
- Partner influence and attribution

#### Example Questions:
- Which accounts have AWS as the primary cloud partner?
- What is the total ARR influenced by partners?
- Which opportunities have partner co-sell involvement?
- What is the marketplace deal velocity by quarter?

---

### 16. Specialized Analytics Tables

Purpose-built analytical tables for specific use cases.

#### Key Tables:
- **`rpt_c360_overview`** - C360 overview report
- **`lakeview_datamap_dashboard`** - Lakeview data mapping
- **`inspection_forecasting`** - Inspection forecast analysis
- **`inspection_regional_summary`** - Regional inspection summaries
- **`consumption_inspection_account_base`** - Consumption inspection base
- **`mau_and_learner_accounts_curated`** - MAU and learner metrics
- **`login_active_users_customer_kpis`** - Customer login KPIs
- **`tech_win_to_go_live_analysis`** - Technical win lifecycle analysis

#### Data Contains:
- Pre-aggregated metrics for dashboards
- Specialized analytical views
- Report-ready data structures

#### Example Questions:
- What is the overview health status across C360 metrics?
- Which accounts show MAU growth but declining consumption?
- What is the technical win to go-live conversion rate?
- Which regions have inspection anomalies?

---

### 17. Miscellaneous & Configuration

Supporting tables for data management and configuration.

#### Key Tables:
- **`c360_dates`** - Date dimension for C360
- **`dummy_reference_dates`** - Reference date table
- **`account_security_predicate_table`** - RLS security predicates
- **`account_data_example`** - Sample/test data
- **`test_table_1`** - Testing table
- **`whitelist__databricks_userid_zoomapi_hostid`** - User whitelisting

---

## Common Query Patterns

### Joining Core Tables

The most common join patterns across GTM data:

```sql
-- Account + Opportunities
SELECT a.*, o.*
FROM main.gtm_data.core_accounts_curated a
JOIN main.gtm_data.core_opportunity_curated o ON a.account_id = o.account_id

-- Account + Consumption
SELECT a.account_name, c.usage_date, c.dbu_dollars
FROM main.gtm_data.core_accounts_curated a
JOIN main.gtm_data.c360_consumption_monthly c ON a.account_id = c.account_id

-- Account + Use Cases
SELECT a.account_name, u.usecase_name, u.stage, u.estimated_monthly_dollars
FROM main.gtm_data.core_accounts_curated a
JOIN main.gtm_data.core_usecase_curated u ON a.account_id = u.account_id

-- Account + Commits
SELECT a.account_name, cm.commit_amount_customer, cm.commit_burn_down_pct
FROM main.gtm_data.core_accounts_curated a
JOIN main.gtm_data.core_commit_measures cm ON a.account_id = cm.account_id

-- Account + Support Cases
SELECT a.account_name, s.CaseNumber, s.Case_Priority, s.Case_Status
FROM main.gtm_data.core_accounts_curated a
JOIN main.gtm_data.support_cases_gold s ON a.account_id = s.Requestor_Account_Id
```

### Time-Series Analysis

Most consumption and metric tables include snapshot_date, usage_date, or fiscal period columns for time-based analysis:

```sql
-- Monthly consumption trend
SELECT
  usage_date,
  SUM(dbu_dollars) as total_consumption
FROM main.gtm_data.c360_consumption_monthly
WHERE account_id = '<account_id>'
  AND usage_date >= '2024-01-01'
GROUP BY usage_date
ORDER BY usage_date
```

### Hierarchical Rollups

Many tables support hierarchical aggregation through sales organization fields:

```sql
-- Rollup by sales hierarchy
SELECT
  sales_region,
  sales_subregion_level_1,
  account_executive,
  COUNT(DISTINCT account_id) as num_accounts,
  SUM(arr) as total_arr
FROM main.gtm_data.core_accounts_curated
GROUP BY sales_region, sales_subregion_level_1, account_executive
```

---

## Data Refresh & Lineage

- **Core Salesforce tables:** Updated daily via ETL pipelines
- **Consumption tables:** Daily/weekly updates from usage tracking systems
- **Curated tables:** Daily refresh with business logic applied
- **Forecast tables:** Updated weekly during forecast cycles
- **Third-party enrichment:** Monthly updates from external vendors
- **Professional Services:** Real-time updates from PSA systems
- **Support Cases:** Near real-time sync from Zendesk/Salesforce

---

## Security & Access

Many tables include Row-Level Security (RLS) variants (suffix: `_rls`) that filter data based on user permissions and sales hierarchy. Always check for RLS versions when building user-facing applications.

Tables with RLS versions:
- `core_accounts_curated` → `combined_targets_rls`
- `commit_clari_forecast_gold` → `commit_clari_forecast_gold_rls`
- `ref_account_upstream_and_direct_hierarchy` → `ref_account_upstream_and_direct_hierarchy_rls`

---

## Key Metrics Definitions

**ARR (Annual Recurring Revenue):** Annualized value of active subscriptions and commits
**T3M (Trailing 3 Months):** Rolling 3-month consumption metric
**DBU (Databricks Unit):** Standard unit of compute consumption
**GRR (Gross Retention Rate):** Renewal rate excluding expansion
**ATR (Available to Renew):** Contract value eligible for renewal
**MAU (Monthly Active Users):** Unique users active in a given month
**TRR (Total Recurring Revenue):** Sum of all recurring revenue streams
**Burn-down:** Consumption progress against commit (% of commit consumed)

---

## Notes

- **Snapshot tables:** Many tables include `snapshot_date` for point-in-time historical analysis
- **Fiscal calendar:** Databricks fiscal year ends January 31
- **Decommissioned columns:** Some tables contain deprecated columns marked as "Decommissioned" in comments
- **Null handling:** Empty strings and nulls may be used inconsistently across different source systems
- **ID fields:** Salesforce IDs are 18-character alphanumeric; Workday IDs follow different format

---

## Related Resources

- **Salesforce:** Source system for accounts, opportunities, cases
- **Workday:** Source for organizational hierarchy and employee data
- **CPQ:** Configure-Price-Quote system for deal structures
- **Clari:** Forecasting and pipeline management platform
- **6sense:** Intent data and account engagement platform

---

## Table Summary by Category

| Category | Table Count | Key Use Cases |
|----------|-------------|---------------|
| Core Accounts & Customers | 25 | Account management, customer segmentation, territory planning |
| Opportunities & Pipeline | 15 | Deal tracking, pipeline analysis, win/loss reporting |
| Consumption (C360) | 30 | Usage analysis, product adoption, consumption forecasting |
| Use Cases | 12 | Implementation tracking, pipeline projections, blocker management |
| Commits & Contracts | 10 | Contract tracking, burn-down analysis, renewal forecasting |
| Forecasting & Targets | 18 | Quota management, forecast accuracy, target attainment |
| Professional Services | 30 | Resource management, project delivery, revenue recognition |
| Support & Success | 15 | Case management, health scoring, customer satisfaction |
| Third-Party Enrichment | 45 | Market intelligence, competitive analysis, intent data |
| Organic Growth | 8 | Growth baseline, trend analysis, projection modeling |
| Hierarchies & References | 12 | Organizational structure, territory mapping, RLS |
| GTM OKRs | 8 | Strategic goal tracking, KPI monitoring |
| Products & SKUs | 6 | Product catalog, adoption metrics, pricing |
| Activities & Meetings | 5 | Engagement tracking, activity metrics |
| Partners & Channels | 8 | Partner co-sell, marketplace deals |
| Specialized Analytics | 15 | Custom reports, dashboard feeds |
| Miscellaneous | 13 | Configuration, testing, reference data |

**Total:** 275 tables
