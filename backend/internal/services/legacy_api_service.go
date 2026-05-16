package services

import (
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"gorm.io/gorm"
)

type LegacyAPIService struct {
	DB *gorm.DB
}

type TreeNode struct {
	ID          string            `json:"id"`
	Title       string            `json:"title"`
	Subtitle    string            `json:"subtitle"`
	Level       int               `json:"level"`
	Count       int64             `json:"count"`
	HasChildren bool              `json:"hasChildren"`
	Filters     map[string]string `json:"filters"`
}

type treeRow struct {
	ID    string
	Title string
	Count int64
}

type TreeResult struct {
	Success bool       `json:"success"`
	Level   int        `json:"level"`
	Data    []TreeNode `json:"data"`
}

type OverviewResult struct {
	Success       bool             `json:"success"`
	CachedAt      string           `json:"cached_at"`
	Metrics       map[string]int64 `json:"metrics"`
	Pipeline      map[string]int64 `json:"pipeline"`
	Engagement    map[string]int64 `json:"engagement"`
	ContentHealth map[string]int64 `json:"contentHealth"`
	Support       map[string]int64 `json:"support"`
	Taxonomy      map[string]int64 `json:"taxonomy"`
	Coverage      map[string]int64 `json:"coverage"`
	Series        map[string]any   `json:"series"`
}

type StatsResult struct {
	Success                bool   `json:"success"`
	CachedAt               string `json:"cached_at"`
	MedicalGuidelines      int64  `json:"medical_guidelines"`
	Drugs                  int64  `json:"drugs"`
	Calculators            int64  `json:"calculators"`
	Abbreviations          int64  `json:"abbreviations"`
	HealthFacilities       int64  `json:"health_facilities"`
	Consultants            int64  `json:"consultants"`
	TotalUsers             int64  `json:"total_users"`
	MinistryDirectory      int64  `json:"ministry_directory"`
	FAQs                   int64  `json:"faqs"`
	UnreadMessagesCount    int64  `json:"unread_messages_count"`
	UserConversationsCount int64  `json:"user_conversations_count"`
}

type DayTotal struct {
	Day   string `json:"day"`
	Total int64  `json:"total"`
}

func ParseTreeRequest(levelRaw string, filtersRaw string, maxLevel int, allowedKeys []string) (int, map[string]string) {
	level := 0
	if parsed, err := parseLevel(levelRaw, maxLevel); err == nil {
		level = parsed
	}
	return level, parseFilterMap(filtersRaw, allowedKeys)
}

func (s LegacyAPIService) ConsultantsTree(level int, filters map[string]string) (TreeResult, error) {
	var rows []treeRow
	query := s.DB.Table("consultants").
		Where("deleted_at IS NULL").
		Where("status IN ?", []string{"active", "pendingApproval", "pending_approval"})

	if value := filters["region"]; value != "" {
		query = query.Where("coalesce(nullif(region, ''), 'Unknown Region') = ?", value)
	}
	if value := filters["city"]; value != "" {
		query = query.Where("coalesce(nullif(city, ''), 'Unknown City') = ?", value)
	}
	if value := filters["specialty"]; value != "" {
		query = query.Where("coalesce(nullif(specialty, ''), 'Other') = ?", value)
	}
	if value := filters["status"]; value != "" {
		query = query.Where("status = ?", value)
	}
	if value, ok := parseBoolFilter(filters["verified"]); ok {
		query = query.Where("is_verified = ?", value)
	}

	switch level {
	case 0:
		err := query.
			Select("coalesce(nullif(region, ''), 'Unknown Region') AS id, coalesce(nullif(region, ''), 'Unknown Region') AS title, count(*) AS count").
			Group("1,2").Order("2").
			Scan(&rows).Error
		return buildTreeResult(level, rows, true, func(r treeRow) map[string]string {
			return map[string]string{"region": r.ID}
		}), err
	case 1:
		err := query.
			Select("coalesce(nullif(city, ''), 'Unknown City') AS id, coalesce(nullif(city, ''), 'Unknown City') AS title, count(*) AS count").
			Group("1,2").Order("2").
			Scan(&rows).Error
		return buildTreeResult(level, rows, true, func(r treeRow) map[string]string {
			return map[string]string{"region": filters["region"], "city": r.ID}
		}), err
	default:
		err := query.
			Select("coalesce(nullif(specialty, ''), 'Other') AS id, coalesce(nullif(specialty, ''), 'Other') AS title, count(*) AS count").
			Group("1,2").Order("2").
			Scan(&rows).Error
		return buildTreeResult(level, rows, false, func(r treeRow) map[string]string {
			return map[string]string{"region": filters["region"], "city": filters["city"], "specialty": r.ID}
		}), err
	}
}

func (s LegacyAPIService) HealthFacilitiesTree(level int, filters map[string]string) (TreeResult, error) {
	var rows []treeRow

	query := s.DB.Table("health_facilities hf").
		Joins("LEFT JOIN regions r ON r.id = hf.region_id").
		Joins("LEFT JOIN districts d ON d.id = hf.district_id").
		Joins("LEFT JOIN facility_levels fl ON fl.id = hf.facility_level_id").
		Where("hf.deleted_at IS NULL")

	if value := filters["region"]; value != "" {
		query = query.Where("hf.region_id::text = ?", value)
	}
	if value := filters["district"]; value != "" {
		query = query.Where("hf.district_id::text = ?", value)
	}
	if value := filters["facility_level"]; value != "" {
		query = query.Where("hf.facility_level_id::text = ?", value)
	}

	switch level {
	case 0:
		err := query.Select("hf.region_id::text AS id, coalesce(r.name, 'Unknown Region') AS title, count(*) AS count").
			Group("hf.region_id, r.name").Order("2").
			Scan(&rows).Error
		return buildTreeResult(level, rows, true, func(r treeRow) map[string]string {
			return map[string]string{"region": r.ID}
		}), err
	case 1:
		err := query.Select("hf.district_id::text AS id, coalesce(d.name, 'Unknown District') AS title, count(*) AS count").
			Group("hf.district_id, d.name").Order("2").
			Scan(&rows).Error
		return buildTreeResult(level, rows, true, func(r treeRow) map[string]string {
			return map[string]string{"region": filters["region"], "district": r.ID}
		}), err
	default:
		err := query.Select("hf.facility_level_id::text AS id, coalesce(fl.name, 'Unknown Facility Level') AS title, count(*) AS count").
			Group("hf.facility_level_id, fl.name").Order("2").
			Scan(&rows).Error
		return buildTreeResult(level, rows, false, func(r treeRow) map[string]string {
			return map[string]string{"region": filters["region"], "district": filters["district"], "facility_level": r.ID}
		}), err
	}
}

func (s LegacyAPIService) MinistryDirectoryTree(level int, filters map[string]string) (TreeResult, error) {
	var rows []treeRow

	query := s.DB.Table("ministry_directory md").
		Joins("LEFT JOIN districts d ON d.id = md.district_id").
		Joins("LEFT JOIN regions reg_direct ON reg_direct.id = md.region_id").
		Joins("LEFT JOIN regions reg_district ON reg_district.id = d.region_id").
		Where("md.deleted_at IS NULL")

	if value := filters["region"]; value != "" {
		query = query.Where("coalesce(reg_direct.name, reg_district.name, 'Unknown Region') = ?", value)
	}
	if value := filters["district"]; value != "" {
		query = query.Where("coalesce(d.name, 'Unknown District') = ?", value)
	}
	if value := filters["ministry"]; value != "" {
		query = query.Where("md.ministry = ?", value)
	}
	if value := filters["department"]; value != "" {
		query = query.Where("coalesce(nullif(md.department, ''), 'Unspecified') = ?", value)
	}
	if value := filters["status"]; value != "" {
		query = query.Where("md.status = ?", value)
	}

	switch level {
	case 0:
		err := query.Select("coalesce(reg_direct.name, reg_district.name, 'Unknown Region') AS id, coalesce(reg_direct.name, reg_district.name, 'Unknown Region') AS title, count(*) AS count").
			Group("1,2").Order("2").
			Scan(&rows).Error
		return buildTreeResult(level, rows, true, func(r treeRow) map[string]string {
			return compactFilterMap(map[string]string{"region": r.ID, "status": filters["status"]})
		}), err
	case 1:
		err := query.Select("coalesce(d.name, 'Unknown District') AS id, coalesce(d.name, 'Unknown District') AS title, count(*) AS count").
			Group("1,2").Order("2").
			Scan(&rows).Error
		return buildTreeResult(level, rows, true, func(r treeRow) map[string]string {
			return compactFilterMap(map[string]string{"region": filters["region"], "district": r.ID, "status": filters["status"]})
		}), err
	default:
		err := query.Select("md.ministry AS id, md.ministry AS title, count(*) AS count").
			Group("1,2").Order("2").
			Scan(&rows).Error
		return buildTreeResult(level, rows, false, func(r treeRow) map[string]string {
			return compactFilterMap(map[string]string{"region": filters["region"], "district": filters["district"], "ministry": r.ID, "status": filters["status"]})
		}), err
	}
}

func (s LegacyAPIService) Overview() (OverviewResult, error) {
	now := time.Now().UTC().Format(time.RFC3339)
	metrics := map[string]int64{}
	pipeline := map[string]int64{}
	engagement := map[string]int64{}
	contentHealth := map[string]int64{}
	support := map[string]int64{}
	taxonomy := map[string]int64{}
	coverage := map[string]int64{}

	var err error
	if metrics["totalUsers"], err = s.count("users", "deleted_at IS NULL"); err != nil {
		return OverviewResult{}, err
	}
	if metrics["activeUsers"], err = s.count("users", "deleted_at IS NULL AND status = ?", "active"); err != nil {
		return OverviewResult{}, err
	}
	metrics["healthcareProviders"], err = s.countHealthcareProviders()
	if err != nil {
		return OverviewResult{}, err
	}
	if metrics["totalDrugs"], err = s.count("drugs", "deleted_at IS NULL"); err != nil {
		return OverviewResult{}, err
	}
	if metrics["activeDrugs"], err = s.count("drugs", "deleted_at IS NULL AND status = ?", "active"); err != nil {
		return OverviewResult{}, err
	}
	if metrics["totalFacilities"], err = s.count("health_facilities", "deleted_at IS NULL"); err != nil {
		return OverviewResult{}, err
	}
	if metrics["totalConsultants"], err = s.count("consultants", "deleted_at IS NULL"); err != nil {
		return OverviewResult{}, err
	}
	if metrics["activeConsultants"], err = s.count("consultants", "deleted_at IS NULL AND status = ?", "active"); err != nil {
		return OverviewResult{}, err
	}

	if pipeline["usersPendingActivation"], err = s.count("users", "deleted_at IS NULL AND status IN ?", []string{"pending_activation", "pendingActivation"}); err != nil {
		return OverviewResult{}, err
	}
	if pipeline["drugsUnderReview"], err = s.count("drugs", "deleted_at IS NULL AND status = ?", "under_review"); err != nil {
		return OverviewResult{}, err
	}
	if pipeline["drugsPendingReview"], err = s.count("drugs", "deleted_at IS NULL AND review_status = ?", "pending"); err != nil {
		return OverviewResult{}, err
	}
	if pipeline["drugsInactive"], err = s.count("drugs", "deleted_at IS NULL AND status = ?", "inactive"); err != nil {
		return OverviewResult{}, err
	}
	if pipeline["consultantsPendingApproval"], err = s.count("consultants", "deleted_at IS NULL AND status IN ?", []string{"pending_approval", "pendingApproval"}); err != nil {
		return OverviewResult{}, err
	}
	if pipeline["consultantsVerified"], err = s.count("consultants", "deleted_at IS NULL AND is_verified = ?", true); err != nil {
		return OverviewResult{}, err
	}

	engagement["aiUsage7d"], err = s.countRecent("ai_usage_logs", 6)
	if err != nil {
		return OverviewResult{}, err
	}
	engagement["aiUsage30d"], err = s.countRecent("ai_usage_logs", 29)
	if err != nil {
		return OverviewResult{}, err
	}
	engagement["calculatorUsage7d"], err = s.countRecent("calculator_usage_logs", 6)
	if err != nil {
		return OverviewResult{}, err
	}
	engagement["calculatorUsage30d"], err = s.countRecent("calculator_usage_logs", 29)
	if err != nil {
		return OverviewResult{}, err
	}
	engagement["guidelineUsage7d"], err = s.countRecent("guideline_usage_logs", 6)
	if err != nil {
		return OverviewResult{}, err
	}
	engagement["guidelineUsage30d"], err = s.countRecent("guideline_usage_logs", 29)
	if err != nil {
		return OverviewResult{}, err
	}
	engagement["drugUsage7d"], err = s.countRecent("drug_usage_logs", 6)
	if err != nil {
		return OverviewResult{}, err
	}
	engagement["drugUsage30d"], err = s.countRecent("drug_usage_logs", 29)
	if err != nil {
		return OverviewResult{}, err
	}
	engagement["facilityUsage7d"], err = s.countRecent("facility_usage_logs", 6)
	if err != nil {
		return OverviewResult{}, err
	}
	engagement["facilityUsage30d"], err = s.countRecent("facility_usage_logs", 29)
	if err != nil {
		return OverviewResult{}, err
	}

	if contentHealth["medicalGuidelinesTotal"], err = s.count("medical_guidelines", "deleted_at IS NULL"); err != nil {
		return OverviewResult{}, err
	}
	if contentHealth["medicalGuidelinesPublished"], err = s.count("medical_guidelines", "deleted_at IS NULL AND (is_published = ? OR status = ?)", true, "published"); err != nil {
		return OverviewResult{}, err
	}
	if contentHealth["medicalGuidelinesDraft"], err = s.count("medical_guidelines", "deleted_at IS NULL AND status = ?", "draft"); err != nil {
		return OverviewResult{}, err
	}
	if contentHealth["faqsTotal"], err = s.count("faqs", "deleted_at IS NULL"); err != nil {
		return OverviewResult{}, err
	}
	if contentHealth["faqsPublished"], err = s.count("faqs", "deleted_at IS NULL AND status = ?", "published"); err != nil {
		return OverviewResult{}, err
	}
	if contentHealth["faqsDraft"], err = s.count("faqs", "deleted_at IS NULL AND status = ?", "draft"); err != nil {
		return OverviewResult{}, err
	}
	if contentHealth["documentationTotal"], err = s.count("documentation", "deleted_at IS NULL"); err != nil {
		return OverviewResult{}, err
	}
	if contentHealth["documentationPublished"], err = s.count("documentation", "deleted_at IS NULL AND status = ?", "published"); err != nil {
		return OverviewResult{}, err
	}
	if contentHealth["genericPagesTotal"], err = s.count("generic_pages", "deleted_at IS NULL"); err != nil {
		return OverviewResult{}, err
	}
	if contentHealth["abbreviationsTotal"], err = s.count("abbreviations", "deleted_at IS NULL"); err != nil {
		return OverviewResult{}, err
	}
	if contentHealth["calculatorsTotal"], err = s.count("calculators", "deleted_at IS NULL"); err != nil {
		return OverviewResult{}, err
	}
	if contentHealth["calculatorsActive"], err = s.count("calculators", "deleted_at IS NULL AND status = ?", "active"); err != nil {
		return OverviewResult{}, err
	}
	if contentHealth["guidelineCategoriesActive"], err = s.count("guideline_categories", "deleted_at IS NULL AND status = ?", "active"); err != nil {
		return OverviewResult{}, err
	}

	if support["ticketsOpen"], err = s.count("support_tickets", "deleted_at IS NULL AND status = ?", "open"); err != nil {
		return OverviewResult{}, err
	}
	if support["ticketsInProgress"], err = s.count("support_tickets", "deleted_at IS NULL AND status = ?", "in_progress"); err != nil {
		return OverviewResult{}, err
	}
	if support["ticketsResolved"], err = s.count("support_tickets", "deleted_at IS NULL AND status = ?", "resolved"); err != nil {
		return OverviewResult{}, err
	}
	if support["ticketsClosed"], err = s.count("support_tickets", "deleted_at IS NULL AND status = ?", "closed"); err != nil {
		return OverviewResult{}, err
	}
	if support["ticketsUrgent"], err = s.count("support_tickets", "deleted_at IS NULL AND priority = ?", "urgent"); err != nil {
		return OverviewResult{}, err
	}
	if support["notifications7d"], err = s.countRecent("notifications", 6); err != nil {
		return OverviewResult{}, err
	}
	if support["notifications30d"], err = s.countRecent("notifications", 29); err != nil {
		return OverviewResult{}, err
	}

	if taxonomy["activeDrugCategories"], err = s.count("drug_categories", "deleted_at IS NULL AND status = ?", "active"); err != nil {
		return OverviewResult{}, err
	}
	if taxonomy["activeDrugClasses"], err = s.count("drug_classes", "deleted_at IS NULL AND status = ?", "active"); err != nil {
		return OverviewResult{}, err
	}
	if taxonomy["activeTherapeuticCategories"], err = s.count("therapeutic_categories", "deleted_at IS NULL AND status = ?", "active"); err != nil {
		return OverviewResult{}, err
	}
	if taxonomy["activeDrugTags"], err = s.count("drug_tags", "deleted_at IS NULL AND status = ?", "active"); err != nil {
		return OverviewResult{}, err
	}

	if coverage["regions"], err = s.count("regions", "deleted_at IS NULL"); err != nil {
		return OverviewResult{}, err
	}
	if coverage["districts"], err = s.count("districts", "deleted_at IS NULL"); err != nil {
		return OverviewResult{}, err
	}
	if coverage["subcounties"], err = s.count("subcounties", "deleted_at IS NULL"); err != nil {
		return OverviewResult{}, err
	}
	if coverage["parishes"], err = s.count("parishes", "deleted_at IS NULL"); err != nil {
		return OverviewResult{}, err
	}

	usersByDay, err := s.seriesCount("users")
	if err != nil {
		return OverviewResult{}, err
	}
	drugsByDay, err := s.seriesCount("drugs")
	if err != nil {
		return OverviewResult{}, err
	}
	facilitiesByDay, err := s.seriesCount("health_facilities")
	if err != nil {
		return OverviewResult{}, err
	}

	return OverviewResult{
		Success:       true,
		CachedAt:      now,
		Metrics:       metrics,
		Pipeline:      pipeline,
		Engagement:    engagement,
		ContentHealth: contentHealth,
		Support:       support,
		Taxonomy:      taxonomy,
		Coverage:      coverage,
		Series: map[string]any{
			"usersByDay":      usersByDay,
			"drugsByDay":      drugsByDay,
			"facilitiesByDay": facilitiesByDay,
		},
	}, nil
}

func (s LegacyAPIService) Stats(userID string) (StatsResult, error) {
	now := time.Now().UTC().Format(time.RFC3339)
	res := StatsResult{Success: true, CachedAt: now}
	var err error

	if res.MedicalGuidelines, err = s.count("medical_guidelines", "deleted_at IS NULL AND status = ?", "published"); err != nil {
		return StatsResult{}, err
	}
	if res.Drugs, err = s.count("drugs", "deleted_at IS NULL AND status = ?", "active"); err != nil {
		return StatsResult{}, err
	}
	if res.Calculators, err = s.count("calculators", "deleted_at IS NULL AND status = ?", "active"); err != nil {
		return StatsResult{}, err
	}
	if res.Abbreviations, err = s.count("abbreviations", "deleted_at IS NULL"); err != nil {
		return StatsResult{}, err
	}
	if res.HealthFacilities, err = s.count("health_facilities", "deleted_at IS NULL"); err != nil {
		return StatsResult{}, err
	}
	if res.Consultants, err = s.count("consultants", "deleted_at IS NULL AND status = ?", "active"); err != nil {
		return StatsResult{}, err
	}
	if res.TotalUsers, err = s.count("users", "deleted_at IS NULL"); err != nil {
		return StatsResult{}, err
	}
	if res.MinistryDirectory, err = s.count("ministry_directory", "deleted_at IS NULL"); err != nil {
		return StatsResult{}, err
	}
	if res.FAQs, err = s.count("faqs", "deleted_at IS NULL AND status = ?", "published"); err != nil {
		return StatsResult{}, err
	}

	if userID != "" {
		if res.UnreadMessagesCount, err = s.unreadMessagesCount(userID); err != nil {
			return StatsResult{}, err
		}
		if res.UserConversationsCount, err = s.userConversationsCount(userID); err != nil {
			return StatsResult{}, err
		}
	}
	return res, nil
}

func (s LegacyAPIService) count(table string, where string, args ...any) (int64, error) {
	var total int64
	err := s.DB.Table(table).Where(where, args...).Count(&total).Error
	return total, err
}

func (s LegacyAPIService) countRecent(table string, daysBack int) (int64, error) {
	var total int64
	sql := fmt.Sprintf("SELECT COUNT(*) FROM %s WHERE deleted_at IS NULL AND created_at::date >= CURRENT_DATE - ?::int", table)
	err := s.DB.Raw(sql, daysBack).Scan(&total).Error
	return total, err
}

func (s LegacyAPIService) countHealthcareProviders() (int64, error) {
	var total int64
	err := s.DB.Raw(`
		SELECT COUNT(DISTINCT u.id)
		FROM users u
		JOIN user_roles ur ON ur.user_id = u.id
		JOIN roles r ON r.id = ur.role_id
		WHERE u.deleted_at IS NULL
		  AND (
		    lower(coalesce(r.role_key, '')) IN ('healthcare_provider', 'healthcareprovider')
		    OR lower(r.name) IN ('healthcare provider', 'healthcare_provider', 'healthcareprovider')
		  )
	`).Scan(&total).Error
	return total, err
}

func (s LegacyAPIService) unreadMessagesCount(userID string) (int64, error) {
	var total int64
	err := s.DB.Raw(`
		SELECT COUNT(*)
		FROM messages m
		WHERE m.deleted_at IS NULL
		  AND m.sender_user_id::text <> ?
		  AND (
		    m.read_by_json IS NULL
		    OR m.read_by_json = '[]'::jsonb
		    OR NOT (m.read_by_json @> to_jsonb(ARRAY[?::text]))
		  )
	`, userID, userID).Scan(&total).Error
	return total, err
}

func (s LegacyAPIService) userConversationsCount(userID string) (int64, error) {
	var total int64
	err := s.DB.Raw(`
		SELECT COUNT(*)
		FROM conversations
		WHERE deleted_at IS NULL
		  AND (participant1_user_id::text = ? OR participant2_user_id::text = ?)
	`, userID, userID).Scan(&total).Error
	return total, err
}

func (s LegacyAPIService) seriesCount(table string) ([]DayTotal, error) {
	var rows []DayTotal
	sql := fmt.Sprintf(`
		WITH days AS (
			SELECT generate_series(CURRENT_DATE - INTERVAL '29 day', CURRENT_DATE, INTERVAL '1 day')::date AS day
		)
		SELECT to_char(days.day, 'YYYY-MM-DD') AS day, COUNT(t.id) AS total
		FROM days
		LEFT JOIN %s t
		  ON t.deleted_at IS NULL
		 AND t.created_at::date = days.day
		GROUP BY days.day
		ORDER BY days.day
	`, table)
	err := s.DB.Raw(sql).Scan(&rows).Error
	return rows, err
}

func parseLevel(raw string, maxLevel int) (int, error) {
	if raw == "" {
		return 0, nil
	}
	var level int
	_, err := fmt.Sscanf(raw, "%d", &level)
	if err != nil {
		return 0, err
	}
	if level < 0 {
		level = 0
	}
	if level > maxLevel {
		level = maxLevel
	}
	return level, nil
}

func parseFilterMap(raw string, allowedKeys []string) map[string]string {
	if raw == "" {
		return map[string]string{}
	}
	var parsed map[string]any
	if err := json.Unmarshal([]byte(raw), &parsed); err != nil {
		return map[string]string{}
	}
	allowed := map[string]bool{}
	for _, key := range allowedKeys {
		allowed[key] = true
	}
	out := map[string]string{}
	for key, value := range parsed {
		if len(allowed) > 0 && !allowed[key] {
			continue
		}
		if value == nil {
			continue
		}
		str := strings.TrimSpace(fmt.Sprint(value))
		if str == "" || len(str) > 120 {
			continue
		}
		out[key] = str
	}
	return out
}

func parseBoolFilter(raw string) (bool, bool) {
	switch strings.ToLower(strings.TrimSpace(raw)) {
	case "true", "1", "yes":
		return true, true
	case "false", "0", "no":
		return false, true
	default:
		return false, false
	}
}

func buildTreeResult(level int, rows []treeRow, hasChildren bool, filterFn func(treeRow) map[string]string) TreeResult {
	nodes := make([]TreeNode, 0, len(rows))
	for _, row := range rows {
		nodes = append(nodes, TreeNode{
			ID:          row.ID,
			Title:       row.Title,
			Subtitle:    "",
			Level:       level,
			Count:       row.Count,
			HasChildren: hasChildren,
			Filters:     filterFn(row),
		})
	}
	return TreeResult{Success: true, Level: level, Data: nodes}
}

func compactFilterMap(in map[string]string) map[string]string {
	out := map[string]string{}
	for k, v := range in {
		if strings.TrimSpace(v) != "" {
			out[k] = v
		}
	}
	return out
}
