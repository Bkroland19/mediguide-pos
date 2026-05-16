package main

import (
	"encoding/json"
	"fmt"
	"strings"

	"mediguide/internal/config"
	"mediguide/internal/db"
	"mediguide/internal/models"
	"mediguide/internal/security"

	"github.com/google/uuid"
	"github.com/rs/zerolog/log"
	"gorm.io/gorm"
	"gorm.io/gorm/clause"
)

var (
	regionID                = uuid.MustParse("11111111-1111-1111-1111-111111111111")
	healthSubRegionID       = uuid.MustParse("11111111-1111-1111-1111-111111111112")
	districtID              = uuid.MustParse("11111111-1111-1111-1111-111111111113")
	countyID                = uuid.MustParse("11111111-1111-1111-1111-111111111114")
	healthSubDistrictID     = uuid.MustParse("11111111-1111-1111-1111-111111111115")
	subcountyID             = uuid.MustParse("11111111-1111-1111-1111-111111111116")
	parishID                = uuid.MustParse("11111111-1111-1111-1111-111111111117")
	facilityLevelHC3ID      = uuid.MustParse("11111111-1111-1111-1111-111111111118")
	facilityLevelHospitalID = uuid.MustParse("11111111-1111-1111-1111-111111111119")
	ownershipTypeGovID      = uuid.MustParse("11111111-1111-1111-1111-111111111120")
	authorityMOHID          = uuid.MustParse("11111111-1111-1111-1111-111111111121")
	authorityDistrictID     = uuid.MustParse("11111111-1111-1111-1111-111111111122")
	facilityID              = uuid.MustParse("11111111-1111-1111-1111-111111111123")
	referralFacilityID      = uuid.MustParse("11111111-1111-1111-1111-111111111124")
	guidelineCategoryID     = uuid.MustParse("11111111-1111-1111-1111-111111111125")
	guidelineTagID          = uuid.MustParse("11111111-1111-1111-1111-111111111126")
	guidelineIndexID        = uuid.MustParse("11111111-1111-1111-1111-111111111127")
	medicalGuidelineID      = uuid.MustParse("11111111-1111-1111-1111-111111111128")
	drugCategoryID          = uuid.MustParse("11111111-1111-1111-1111-111111111129")
	drugTagID               = uuid.MustParse("11111111-1111-1111-1111-111111111130")
	drugClassID             = uuid.MustParse("11111111-1111-1111-1111-111111111131")
	therapeuticCategoryID   = uuid.MustParse("11111111-1111-1111-1111-111111111132")
	drugID                  = uuid.MustParse("11111111-1111-1111-1111-111111111133")
	calculatorID            = uuid.MustParse("11111111-1111-1111-1111-111111111134")
	abbreviationID          = uuid.MustParse("11111111-1111-1111-1111-111111111135")
	emergencyProtocolID     = uuid.MustParse("11111111-1111-1111-1111-111111111136")
	genericPageID           = uuid.MustParse("11111111-1111-1111-1111-111111111137")
	faqTagID                = uuid.MustParse("11111111-1111-1111-1111-111111111138")
	faqID                   = uuid.MustParse("11111111-1111-1111-1111-111111111139")
	documentationID         = uuid.MustParse("11111111-1111-1111-1111-111111111140")
	settingID               = uuid.MustParse("11111111-1111-1111-1111-111111111141")
	languageENID            = uuid.MustParse("11111111-1111-1111-1111-111111111142")
	languageSWID            = uuid.MustParse("11111111-1111-1111-1111-111111111143")
	consultantOneID         = uuid.MustParse("11111111-1111-1111-1111-111111111144")
	consultantTwoID         = uuid.MustParse("11111111-1111-1111-1111-111111111145")
	ministryDirectoryID     = uuid.MustParse("11111111-1111-1111-1111-111111111146")
	notificationID          = uuid.MustParse("11111111-1111-1111-1111-111111111147")
	notificationTemplateID  = uuid.MustParse("11111111-1111-1111-1111-111111111148")
	notificationCampaignID  = uuid.MustParse("11111111-1111-1111-1111-111111111149")
	supportTicketID         = uuid.MustParse("11111111-1111-1111-1111-111111111150")
	supportReplyID          = uuid.MustParse("11111111-1111-1111-1111-111111111151")
	conversationID          = uuid.MustParse("11111111-1111-1111-1111-111111111152")
	messageID               = uuid.MustParse("11111111-1111-1111-1111-111111111153")
	guidelineDocumentID     = uuid.MustParse("11111111-1111-1111-1111-111111111154")
	guidelineVersionID      = uuid.MustParse("11111111-1111-1111-1111-111111111155")
	guidelineSectionIntroID = uuid.MustParse("11111111-1111-1111-1111-111111111164")
	guidelineSectionMgmtID  = uuid.MustParse("11111111-1111-1111-1111-111111111165")
	guidelineChunkIntroID   = uuid.MustParse("11111111-1111-1111-1111-111111111166")
	guidelineChunkTreatID   = uuid.MustParse("11111111-1111-1111-1111-111111111167")
	guidelineTableID        = uuid.MustParse("11111111-1111-1111-1111-111111111168")
	guidelineIngestionJobID = uuid.MustParse("11111111-1111-1111-1111-111111111169")
	readingProgressID       = uuid.MustParse("11111111-1111-1111-1111-111111111156")
	calculatorUsageLogID    = uuid.MustParse("11111111-1111-1111-1111-111111111157")
	guidelineUsageLogID     = uuid.MustParse("11111111-1111-1111-1111-111111111158")
	drugUsageLogID          = uuid.MustParse("11111111-1111-1111-1111-111111111159")
	abbreviationUsageLogID  = uuid.MustParse("11111111-1111-1111-1111-111111111160")
	consultantUsageLogID    = uuid.MustParse("11111111-1111-1111-1111-111111111161")
	facilityUsageLogID      = uuid.MustParse("11111111-1111-1111-1111-111111111162")
	aiUsageLogID            = uuid.MustParse("11111111-1111-1111-1111-111111111163")
)

func main() {
	cfg := config.Load()
	database, err := db.Connect(cfg.DatabaseURL)
	if err != nil {
		log.Fatal().Err(err).Msg("db connect failed")
	}

	admin, clinician, err := seedSecurity(database)
	if err != nil {
		log.Fatal().Err(err).Msg("seed security failed")
	}
	if err := seedLegacyData(database, admin, clinician); err != nil {
		log.Fatal().Err(err).Msg("seed legacy data failed")
	}

	log.Info().Msg("seed completed")
}

func seedSecurity(database *gorm.DB) (*models.User, *models.User, error) {
	permissions := []models.Permission{
		{Code: "guideline.read", Name: "Read guidelines"},
		{Code: "guideline.write", Name: "Create/update guidelines"},
		{Code: "guideline.publish", Name: "Publish guidelines"},
		{Code: "protocol.read", Name: "Read protocols"},
		{Code: "protocol.write", Name: "Create/update protocols"},
		{Code: "chat.ask", Name: "Ask RAG chatbot"},
		{Code: "sync.read", Name: "Read sync packages"},
		{Code: "admin.all", Name: "All administration permissions"},
	}
	for i := range permissions {
		if err := database.Where(models.Permission{Code: permissions[i].Code}).Assign(permissions[i]).FirstOrCreate(&permissions[i]).Error; err != nil {
			return nil, nil, err
		}
	}

	adminRole := models.Role{Name: "admin"}
	adminRoleKey := "admin"
	if err := database.Where(models.Role{Name: "admin"}).Assign(models.Role{
		Name:        "admin",
		RoleKey:     &adminRoleKey,
		Description: "System administrator",
		IsActive:    true,
	}).FirstOrCreate(&adminRole).Error; err != nil {
		return nil, nil, err
	}
	if err := database.Model(&adminRole).Association("Permissions").Replace(&permissions); err != nil {
		return nil, nil, err
	}

	clinicianRole := models.Role{Name: "clinician"}
	clinicianRoleKey := "healthcare_provider"
	if err := database.Where(models.Role{Name: "clinician"}).Assign(models.Role{
		Name:        "clinician",
		RoleKey:     &clinicianRoleKey,
		Description: "Frontline clinician",
		IsActive:    true,
	}).FirstOrCreate(&clinicianRole).Error; err != nil {
		return nil, nil, err
	}
	clinicianPerms := []models.Permission{
		permissions[0],
		permissions[3],
		permissions[5],
		permissions[6],
	}
	if err := database.Model(&clinicianRole).Association("Permissions").Replace(&clinicianPerms); err != nil {
		return nil, nil, err
	}

	adminHash, err := security.HashPassword("Admin123!")
	if err != nil {
		return nil, nil, err
	}
	admin := models.User{Email: "admin@mediguide.local"}
	if err := database.Where(models.User{Email: admin.Email}).Assign(models.User{
		Name:         "MediGuide Admin",
		Email:        admin.Email,
		Phone:        "+256700000001",
		PasswordHash: adminHash,
		IsActive:     true,
		Verified:     true,
		Status:       "active",
	}).FirstOrCreate(&admin).Error; err != nil {
		return nil, nil, err
	}
	if err := database.Model(&admin).Association("Roles").Replace(&adminRole); err != nil {
		return nil, nil, err
	}

	clinicianHash, err := security.HashPassword("Clinician123!")
	if err != nil {
		return nil, nil, err
	}
	clinician := models.User{Email: "clinician@mediguide.local"}
	preferredLanguage := "en"
	organization := "Kampala Central Health Centre III"
	specialization := "General Practice"
	if err := database.Where(models.User{Email: clinician.Email}).Assign(models.User{
		Name:              "MediGuide Clinician",
		Email:             clinician.Email,
		Phone:             "+256700000002",
		PasswordHash:      clinicianHash,
		IsActive:          true,
		Verified:          true,
		Status:            "active",
		Organization:      &organization,
		PreferredLanguage: &preferredLanguage,
		Specialization:    &specialization,
	}).FirstOrCreate(&clinician).Error; err != nil {
		return nil, nil, err
	}
	if err := database.Model(&clinician).Association("Roles").Replace(&clinicianRole); err != nil {
		return nil, nil, err
	}

	return &admin, &clinician, nil
}

func seedLegacyData(database *gorm.DB, admin, clinician *models.User) error {
	rows := []struct {
		table string
		row   map[string]any
	}{
		{
			table: "settings",
			row: map[string]any{
				"id":          settingID,
				"key":         "app.support_email",
				"value_json":  mustJSON(`{"value":"support@mediguide.local"}`),
				"category":    "app",
				"description": "Primary support email address",
				"is_public":   true,
			},
		},
		{
			table: "languages",
			row: map[string]any{
				"id":                languageENID,
				"code":              "en",
				"name":              "English",
				"native_name":       "English",
				"is_active":         true,
				"is_default":        true,
				"translations_url":  "https://example.com/i18n/en.json",
				"translations_json": mustJSON(`{"welcome":"Welcome"}`),
				"version":           1.0,
				"status":            "active",
				"progress":          100.0,
				"enabled_for_users": true,
			},
		},
		{
			table: "languages",
			row: map[string]any{
				"id":                languageSWID,
				"code":              "sw",
				"name":              "Swahili",
				"native_name":       "Kiswahili",
				"is_active":         true,
				"is_default":        false,
				"translations_url":  "https://example.com/i18n/sw.json",
				"translations_json": mustJSON(`{"welcome":"Karibu"}`),
				"version":           1.0,
				"status":            "active",
				"progress":          82.0,
				"enabled_for_users": true,
			},
		},
		{
			table: "regions",
			row: map[string]any{
				"id":        regionID,
				"name":      "Central Region",
				"nhpi_code": "REG-C-001",
				"hsdt_code": "HSDT-C-001",
			},
		},
		{
			table: "health_sub_regions",
			row: map[string]any{
				"id":        healthSubRegionID,
				"region_id": regionID,
				"name":      "Greater Kampala",
				"nhpi_code": "HSR-C-001",
				"hsdt_code": "HSDT-HSR-001",
			},
		},
		{
			table: "districts",
			row: map[string]any{
				"id":                   districtID,
				"health_sub_region_id": healthSubRegionID,
				"region_id":            regionID,
				"name":                 "Kampala",
				"nhpi_code":            "DST-C-001",
				"hsdt_code":            "HSDT-DST-001",
			},
		},
		{
			table: "counties",
			row: map[string]any{
				"id":          countyID,
				"district_id": districtID,
				"name":        "Kampala Central",
				"nhpi_code":   "CNT-C-001",
				"hsdt_code":   "HSDT-CNT-001",
			},
		},
		{
			table: "health_sub_districts",
			row: map[string]any{
				"id":          healthSubDistrictID,
				"district_id": districtID,
				"name":        "Kampala Central Division",
				"nhpi_code":   "HSD-C-001",
				"hsdt_code":   "HSDT-HSD-001",
			},
		},
		{
			table: "subcounties",
			row: map[string]any{
				"id":          subcountyID,
				"county_id":   countyID,
				"district_id": districtID,
				"name":        "Nakasero",
				"nhpi_code":   "SUB-C-001",
				"hsdt_code":   "HSDT-SUB-001",
			},
		},
		{
			table: "parishes",
			row: map[string]any{
				"id":           parishID,
				"subcounty_id": subcountyID,
				"name":         "Nakasero Parish",
				"nhpi_code":    "PAR-C-001",
				"hsdt_code":    "HSDT-PAR-001",
			},
		},
		{
			table: "facility_levels",
			row: map[string]any{
				"id":   facilityLevelHC3ID,
				"code": "HCIII",
				"name": "Health Centre III",
			},
		},
		{
			table: "facility_levels",
			row: map[string]any{
				"id":   facilityLevelHospitalID,
				"code": "HOSP",
				"name": "General Hospital",
			},
		},
		{
			table: "ownership_types",
			row: map[string]any{
				"id":   ownershipTypeGovID,
				"code": "GOV",
				"name": "Government",
			},
		},
		{
			table: "authorities",
			row: map[string]any{
				"id":                authorityMOHID,
				"name":              "Ministry of Health",
				"code":              "MOH",
				"ownership_type_id": ownershipTypeGovID,
			},
		},
		{
			table: "authorities",
			row: map[string]any{
				"id":                authorityDistrictID,
				"name":              "Kampala Capital City Authority",
				"code":              "KCCA",
				"ownership_type_id": ownershipTypeGovID,
			},
		},
		{
			table: "health_facilities",
			row: map[string]any{
				"id":                     facilityID,
				"name":                   "Kampala Central Health Centre III",
				"nhpi_code":              "FAC-C-001",
				"hsdt_code":              "HSDT-FAC-001",
				"facility_level_id":      facilityLevelHC3ID,
				"authority_id":           authorityDistrictID,
				"ownership_type_id":      ownershipTypeGovID,
				"health_sub_district_id": healthSubDistrictID,
				"parish_id":              parishID,
				"subcounty_id":           subcountyID,
				"county_id":              countyID,
				"district_id":            districtID,
				"health_sub_region_id":   healthSubRegionID,
				"region_id":              regionID,
				"usage_count":            15,
			},
		},
		{
			table: "health_facilities",
			row: map[string]any{
				"id":                     referralFacilityID,
				"name":                   "Kampala General Hospital",
				"nhpi_code":              "FAC-C-002",
				"hsdt_code":              "HSDT-FAC-002",
				"facility_level_id":      facilityLevelHospitalID,
				"authority_id":           authorityMOHID,
				"ownership_type_id":      ownershipTypeGovID,
				"health_sub_district_id": healthSubDistrictID,
				"parish_id":              parishID,
				"subcounty_id":           subcountyID,
				"county_id":              countyID,
				"district_id":            districtID,
				"health_sub_region_id":   healthSubRegionID,
				"region_id":              regionID,
				"usage_count":            9,
			},
		},
		{
			table: "consultants",
			row: map[string]any{
				"id":                  consultantOneID,
				"user_id":             admin.ID,
				"name":                "Dr Sarah Kintu",
				"email":               "sarah.kintu@mediguide.local",
				"phone":               "+256700100001",
				"specialty":           "Infectious Diseases",
				"city":                "Kampala",
				"region":              "Central Region",
				"country":             "Uganda",
				"organization":        "Ministry of Health",
				"department":          "Clinical Services",
				"preferred_language":  "en",
				"timezone":            "Africa/Kampala",
				"consultation_types":  "phone,chat",
				"status":              "active",
				"is_verified":         true,
				"rating":              4.8,
				"total_consultations": 124,
				"usage_count":         25,
			},
		},
		{
			table: "consultants",
			row: map[string]any{
				"id":                  consultantTwoID,
				"user_id":             clinician.ID,
				"name":                "Dr Grace Nambi",
				"email":               "grace.nambi@mediguide.local",
				"phone":               "+256700100002",
				"specialty":           "Pediatrics",
				"city":                "Kampala",
				"region":              "Central Region",
				"country":             "Uganda",
				"organization":        "Kampala Central Health Centre III",
				"preferred_language":  "en",
				"timezone":            "Africa/Kampala",
				"consultation_types":  "chat",
				"status":              "active",
				"is_verified":         true,
				"rating":              4.6,
				"total_consultations": 80,
				"usage_count":         18,
			},
		},
		{
			table: "ministry_directory",
			row: map[string]any{
				"id":                 ministryDirectoryID,
				"district_id":        districtID,
				"region_id":          regionID,
				"name":               "Emergency Operations Desk",
				"title":              "National Rapid Response Focal Person",
				"ministry":           "Ministry of Health",
				"department":         "Public Health Emergency Operations Centre",
				"phone":              "+256312000001",
				"email":              "rapid.response@health.go.ug",
				"office_address":     "Plot 6 Lourdel Road, Nakasero",
				"priority_level":     1,
				"availability_hours": "24/7",
				"specialization":     "Emergency coordination",
				"status":             "active",
			},
		},
		{
			table: "guideline_categories",
			row: map[string]any{
				"id":          guidelineCategoryID,
				"name":        "Malaria",
				"slug":        "malaria",
				"description": "Malaria case management",
				"sort_order":  1,
				"status":      "active",
				"color":       "#0f766e",
				"icon":        "mosquito",
			},
		},
		{
			table: "guideline_tags",
			row: map[string]any{
				"id":          guidelineTagID,
				"name":        "adult-care",
				"description": "Adult patient care",
			},
		},
		{
			table: "guideline_index",
			row: map[string]any{
				"id":           guidelineIndexID,
				"title":        "Malaria Management",
				"sort_order":   1,
				"description":  "High-priority malaria pathways",
				"level":        1,
				"has_children": false,
			},
		},
		{
			table: "medical_guidelines",
			row: map[string]any{
				"id":                        medicalGuidelineID,
				"index_item_id":             guidelineIndexID,
				"condition_name":            "Severe Malaria",
				"icd10_code":                "B50.8",
				"target_population":         "Adults and adolescents",
				"definition":                "Life-threatening malaria with evidence of organ dysfunction.",
				"clinical_features":         "Altered consciousness, severe anemia, respiratory distress.",
				"general_management":        "Stabilize airway, breathing, circulation and confirm malaria urgently.",
				"medication_primary":        "Artesunate IV",
				"dosage_adult":              "2.4 mg/kg IV at 0, 12 and 24 hours, then daily.",
				"healthcare_level_required": "Hospital",
				"monitoring_requirements":   "Glucose, urine output, hemoglobin and neurologic status.",
				"prevention_measures":       "Vector control, chemoprophylaxis and prompt treatment.",
				"special_notes":             "Refer early if dialysis or ventilatory support may be needed.",
				"status":                    "published",
				"is_published":              true,
				"priority":                  "high",
				"version":                   "2026.1",
				"categories_json":           mustJSON(`["11111111-1111-1111-1111-111111111125"]`),
				"tags_json":                 mustJSON(`["11111111-1111-1111-1111-111111111126"]`),
				"usage_count":               21,
			},
		},
		{
			table: "drug_categories",
			row: map[string]any{
				"id":          drugCategoryID,
				"name":        "Antimalarials",
				"description": "Therapies used in malaria treatment",
				"color":       "#15803d",
				"icon":        "pill",
				"sort_order":  1,
				"status":      "active",
			},
		},
		{
			table: "drug_tags",
			row: map[string]any{
				"id":           drugTagID,
				"name":         "essential",
				"description":  "Core essential medicine",
				"color":        "#dc2626",
				"tag_category": "formulary",
				"sort_order":   1,
				"status":       "active",
			},
		},
		{
			table: "drug_classes",
			row: map[string]any{
				"id":          drugClassID,
				"name":        "Artemisinin Derivatives",
				"description": "Rapid-acting antimalarial agents",
				"sort_order":  1,
				"status":      "active",
			},
		},
		{
			table: "therapeutic_categories",
			row: map[string]any{
				"id":          therapeuticCategoryID,
				"name":        "Antiprotozoals",
				"description": "Antiprotozoal medicines",
				"sort_order":  1,
				"status":      "active",
			},
		},
		{
			table: "drugs",
			row: map[string]any{
				"id":                      drugID,
				"drug_class_id":           drugClassID,
				"therapeutic_category_id": therapeuticCategoryID,
				"name":                    "Artesunate",
				"brand_names":             "Arinate",
				"description":             "Preferred treatment for severe malaria.",
				"adult_dose":              "2.4 mg/kg IV at 0, 12 and 24 hours, then daily.",
				"pediatric_dose":          "2.4 mg/kg IV at 0, 12 and 24 hours, then daily.",
				"route_of_administration": "IV/IM",
				"indications":             "Severe malaria",
				"side_effects":            "Transient neutropenia, delayed hemolysis.",
				"warnings":                "Monitor for post-artesunate hemolysis.",
				"categories_json":         mustJSON(`["11111111-1111-1111-1111-111111111129"]`),
				"tags_json":               mustJSON(`["11111111-1111-1111-1111-111111111130"]`),
				"who_eml_status":          true,
				"antimicrobial_status":    false,
				"status":                  "active",
				"review_status":           "approved",
				"search_keywords":         "malaria artesunate severe malaria",
				"usage_count":             34,
			},
		},
		{
			table: "abbreviations",
			row: map[string]any{
				"id":           abbreviationID,
				"abbreviation": "ACT",
				"meaning":      "Artemisinin-based Combination Therapy",
				"description":  "Standard malaria treatment abbreviation.",
				"common_usage": true,
				"usage_count":  12,
			},
		},
		{
			table: "calculators",
			row: map[string]any{
				"id":               calculatorID,
				"added_by_user_id": admin.ID,
				"name":             "Pediatric Weight Dosing",
				"description":      "Calculate safe weight-based dosing for emergency care.",
				"icon":             "calculator",
				"color":            "#0284c7",
				"background_color": "#e0f2fe",
				"app_file_json":    mustJSON(`{"path":"calculators/pediatric-weight-dosing.html","size":2048}`),
				"version":          "1.0.0",
				"type":             "html",
				"status":           "active",
				"usage_count":      11,
				"featured":         true,
			},
		},
		{
			table: "emergency_protocols",
			row: map[string]any{
				"id":                      emergencyProtocolID,
				"title":                   "Initial Stabilization of Severe Malaria",
				"description":             "Rapid emergency protocol for first-hour stabilization.",
				"category":                "infectious-diseases",
				"priority":                "1",
				"timeframe":               "first_hour",
				"steps_json":              mustJSON(`[{"step":"Assess airway and breathing"},{"step":"Check glucose and treat hypoglycemia"},{"step":"Start IV artesunate"}]`),
				"critical_actions_json":   mustJSON(`["Check glucose","Start IV artesunate"]`),
				"medications_json":        mustJSON(`[{"name":"Artesunate","dose":"2.4 mg/kg IV"}]`),
				"contact_info_json":       mustJSON(`{"referral":"+256312000001"}`),
				"transfer_checklist_json": mustJSON(`["Referral note","Vitals chart","IV access secured"]`),
				"status":                  "active",
				"access_count":            7,
				"vital_signs_json":        mustJSON(`{"monitor":["pulse","bp","respiratory_rate","temperature"]}`),
				"tags_json":               mustJSON(`["malaria","emergency"]`),
			},
		},
		{
			table: "generic_pages",
			row: map[string]any{
				"id":           genericPageID,
				"title":        "About MediGuide",
				"description":  "Overview of the platform",
				"content_json": mustJSON(`{"blocks":[{"type":"paragraph","text":"MediGuide provides evidence-based bedside support."}]}`),
				"key":          "about",
			},
		},
		{
			table: "faq_tags",
			row: map[string]any{
				"id":          faqTagID,
				"name":        "getting-started",
				"slug":        "getting-started",
				"description": "Frequently asked onboarding questions",
				"color":       "#16a34a",
				"icon":        "help-circle",
				"usage_count": 1,
				"is_active":   true,
				"sort_order":  1,
			},
		},
		{
			table: "faqs",
			row: map[string]any{
				"id":                faqID,
				"author_id":         admin.ID,
				"reviewer_id":       clinician.ID,
				"question":          "How do I access offline guidelines?",
				"answer":            "Open the sync section, download the latest package and refresh the local library.",
				"status":            "published",
				"priority":          "high",
				"sort_order":        1,
				"is_featured":       true,
				"target_audience":   "healthcareProvider",
				"keywords":          "offline sync guidelines mobile",
				"published_at":      "2026-05-16T00:00:00Z",
				"review_due":        "2026-11-16T00:00:00Z",
				"tags_json":         mustJSON(`["getting-started"]`),
				"related_faqs_json": mustJSON(`[]`),
			},
		},
		{
			table: "documentation",
			row: map[string]any{
				"id":          documentationID,
				"title":       "Clinical Content Review Workflow",
				"description": "Editorial workflow for publishing content",
				"content":     "Draft content is reviewed by a clinician, then published by an administrator.",
				"category":    "operations",
				"tags":        "editorial,workflow",
				"status":      "published",
			},
		},
		{
			table: "guideline_documents",
			row: map[string]any{
				"id":                 guidelineDocumentID,
				"title":              "Uganda Malaria Guideline",
				"country":            "Uganda",
				"source_org":         "Ministry of Health",
				"program_area":       "Malaria",
				"language":           "en",
				"description":        "Source document used for structured chunks and sync packages.",
				"current_version_id": nil,
			},
		},
		{
			table: "guideline_versions",
			row: map[string]any{
				"id":                guidelineVersionID,
				"document_id":       guidelineDocumentID,
				"version":           "2026.1",
				"publication_date":  "2026-05-16",
				"review_date":       "2026-11-16",
				"status":            "published",
				"original_file_key": "guidelines/11111111-1111-1111-1111-111111111155/original/seed_malaria_guideline.pdf",
				"html_file_key":     "guidelines/11111111-1111-1111-1111-111111111155/extracted/seed_malaria_guideline.html",
				"markdown_file_key": "guidelines/11111111-1111-1111-1111-111111111155/extracted/seed_malaria_guideline.md",
				"checksum":          "seed-malaria-guideline-2026",
				"approved_by":       admin.ID,
				"approved_at":       "2026-05-16T09:00:00Z",
			},
		},
		{
			table: "guideline_sections",
			row: map[string]any{
				"id":         guidelineSectionIntroID,
				"version_id": guidelineVersionID,
				"title":      "Initial assessment",
				"slug":       "initial-assessment",
				"level":      1,
				"html":       "<h1 id=\"initial-assessment\">Initial assessment</h1><p>Assess airway, breathing, circulation, glucose and neurologic status immediately.</p>",
				"text":       "Assess airway, breathing, circulation, glucose and neurologic status immediately.",
				"page_start": 1,
				"page_end":   1,
				"sort_order": 0,
			},
		},
		{
			table: "guideline_sections",
			row: map[string]any{
				"id":         guidelineSectionMgmtID,
				"version_id": guidelineVersionID,
				"title":      "Severe malaria treatment",
				"slug":       "severe-malaria-treatment",
				"level":      1,
				"html":       "<h1 id=\"severe-malaria-treatment\">Severe malaria treatment</h1><p>Start intravenous artesunate, treat hypoglycemia, and refer to hospital-level care if advanced support is required.</p>",
				"text":       "Start intravenous artesunate, treat hypoglycemia, and refer to hospital-level care if advanced support is required.",
				"page_start": 2,
				"page_end":   3,
				"sort_order": 1,
			},
		},
		{
			table: "guideline_tables",
			row: map[string]any{
				"id":         guidelineTableID,
				"version_id": guidelineVersionID,
				"section_id": guidelineSectionMgmtID,
				"title":      "First-line severe malaria dosing",
				"html":       "<table><tr><td>Population</td><td>Dose</td></tr><tr><td>Adult</td><td>2.4 mg/kg IV artesunate</td></tr><tr><td>Child</td><td>2.4 mg/kg IV artesunate</td></tr></table>",
				"data_json":  mustJSON(`[["Population","Dose"],["Adult","2.4 mg/kg IV artesunate"],["Child","2.4 mg/kg IV artesunate"]]`),
				"page":       2,
			},
		},
		{
			table: "ingestion_jobs",
			row: map[string]any{
				"id":           guidelineIngestionJobID,
				"version_id":   guidelineVersionID,
				"job_type":     "pdf_ingestion",
				"status":       "completed",
				"error":        "",
				"payload_json": mustJSON(`{"file_key":"guidelines/11111111-1111-1111-1111-111111111155/original/seed_malaria_guideline.pdf"}`),
				"started_at":   "2026-05-16T08:45:00Z",
				"completed_at": "2026-05-16T08:47:00Z",
			},
		},
		{
			table: "support_tickets",
			row: map[string]any{
				"id":          supportTicketID,
				"user_id":     clinician.ID,
				"assigned_to": admin.ID,
				"subject":     "Offline package not refreshing",
				"description": "Downloaded package completes, but the mobile library still shows old content.",
				"status":      "open",
				"priority":    "high",
				"category":    "sync",
			},
		},
		{
			table: "support_ticket_replies",
			row: map[string]any{
				"id":          supportReplyID,
				"ticket_id":   supportTicketID,
				"user_id":     admin.ID,
				"message":     "We are checking the package manifest timestamps and will follow up shortly.",
				"is_internal": false,
			},
		},
		{
			table: "notifications",
			row: map[string]any{
				"id":         notificationID,
				"user_id":    clinician.ID,
				"title":      "New malaria package available",
				"message":    "Guideline updates for malaria have been published and are ready for sync.",
				"type":       "content",
				"priority":   "high",
				"action_url": "/sync",
			},
		},
		{
			table: "notification_templates",
			row: map[string]any{
				"id":             notificationTemplateID,
				"name":           "Guideline update alert",
				"type":           "push",
				"category":       "content",
				"status":         "active",
				"subject":        "Updated guideline available",
				"content":        "A new guideline package is available for {{program_area}}.",
				"audience":       "healthcareProvider",
				"variables_json": mustJSON(`["program_area"]`),
			},
		},
		{
			table: "notification_campaigns",
			row: map[string]any{
				"id":                      notificationCampaignID,
				"name":                    "Malaria content launch",
				"type":                    "content-update",
				"channels_json":           mustJSON(`["push","in_app"]`),
				"status":                  "scheduled",
				"audience_total":          1200,
				"audience_countries_json": mustJSON(`["UG"]`),
				"audience_roles_json":     mustJSON(`["healthcareProvider"]`),
				"schedule_start":          "2026-05-16T09:00:00Z",
				"schedule_end":            "2026-05-16T18:00:00Z",
			},
		},
		{
			table: "conversations",
			row: map[string]any{
				"id":                   conversationID,
				"participant1_user_id": admin.ID,
				"participant2_user_id": clinician.ID,
				"last_activity":        "2026-05-16T08:45:00Z",
			},
		},
		{
			table: "messages",
			row: map[string]any{
				"id":               messageID,
				"conversation_id":  conversationID,
				"sender_user_id":   admin.ID,
				"content":          "Please pull the latest sync package after we publish the malaria update.",
				"message_type":     "text",
				"attachments_json": mustJSON(`[]`),
				"read_by_json":     mustJSON(`[]`),
				"reactions_json":   mustJSON(`[]`),
				"is_edited":        false,
			},
		},
		{
			table: "reading_progress",
			row: map[string]any{
				"id":                    readingProgressID,
				"user_id":               clinician.ID,
				"guideline_document_id": guidelineDocumentID,
				"progress_percentage":   68.0,
				"current_section":       "Severe malaria stabilization",
				"last_read_at":          "2026-05-16T08:30:00Z",
				"is_bookmarked":         true,
				"reading_time_seconds":  1540,
			},
		},
		{
			table: "calculator_usage_logs",
			row: map[string]any{
				"id":              calculatorUsageLogID,
				"user_id":         clinician.ID,
				"calculator_id":   calculatorID,
				"session_start":   "2026-05-16T08:00:00Z",
				"session_end":     "2026-05-16T08:05:00Z",
				"calculator_type": "html",
			},
		},
		{
			table: "guideline_usage_logs",
			row: map[string]any{
				"id":                    guidelineUsageLogID,
				"user_id":               clinician.ID,
				"guideline_document_id": guidelineDocumentID,
			},
		},
		{
			table: "drug_usage_logs",
			row: map[string]any{
				"id":      drugUsageLogID,
				"user_id": clinician.ID,
				"drug_id": drugID,
			},
		},
		{
			table: "abbreviation_usage_logs",
			row: map[string]any{
				"id":              abbreviationUsageLogID,
				"user_id":         clinician.ID,
				"abbreviation_id": abbreviationID,
			},
		},
		{
			table: "consultant_usage_logs",
			row: map[string]any{
				"id":            consultantUsageLogID,
				"user_id":       clinician.ID,
				"consultant_id": consultantOneID,
			},
		},
		{
			table: "facility_usage_logs",
			row: map[string]any{
				"id":          facilityUsageLogID,
				"user_id":     clinician.ID,
				"facility_id": facilityID,
			},
		},
		{
			table: "ai_usage_logs",
			row: map[string]any{
				"id":      aiUsageLogID,
				"user_id": clinician.ID,
			},
		},
	}

	for _, entry := range rows {
		if err := upsertByID(database, entry.table, entry.row); err != nil {
			return err
		}
	}

	if err := upsertGuidelineChunk(
		database,
		guidelineChunkIntroID,
		guidelineVersionID,
		guidelineSectionIntroID,
		"Initial assessment",
		"Assess airway, breathing, circulation, glucose and neurologic status immediately in every patient with suspected severe malaria.",
		"<p>Assess airway, breathing, circulation, glucose and neurologic status immediately in every patient with suspected severe malaria.</p>",
		1,
		1,
		"en",
		"Malaria",
		"Ministry of Health",
		"2026.1",
		"approved",
		0,
	); err != nil {
		return err
	}

	if err := upsertGuidelineChunk(
		database,
		guidelineChunkTreatID,
		guidelineVersionID,
		guidelineSectionMgmtID,
		"Severe malaria treatment",
		"Start intravenous artesunate promptly, manage hypoglycemia, monitor urine output, and refer for advanced supportive care when indicated.",
		"<p>Start intravenous artesunate promptly, manage hypoglycemia, monitor urine output, and refer for advanced supportive care when indicated.</p>",
		2,
		3,
		"en",
		"Malaria",
		"Ministry of Health",
		"2026.1",
		"approved",
		1,
	); err != nil {
		return err
	}

	return database.Table("guideline_documents").
		Where("id = ?", guidelineDocumentID).
		Update("current_version_id", guidelineVersionID).Error
}

func upsertByID(database *gorm.DB, table string, row map[string]any) error {
	assignments := map[string]any{}
	for key, value := range row {
		if key == "id" {
			continue
		}
		assignments[key] = value
	}
	return database.Table(table).
		Clauses(clause.OnConflict{
			Columns:   []clause.Column{{Name: "id"}},
			DoUpdates: clause.Assignments(assignments),
		}).
		Create(row).Error
}

func mustJSON(raw string) json.RawMessage {
	return json.RawMessage(raw)
}

func upsertGuidelineChunk(
	database *gorm.DB,
	id uuid.UUID,
	versionID uuid.UUID,
	sectionID uuid.UUID,
	title string,
	content string,
	html string,
	pageStart int,
	pageEnd int,
	language string,
	programArea string,
	sourceName string,
	sourceVersion string,
	reviewStatus string,
	vectorSeed int,
) error {
	return database.Exec(
		`
		INSERT INTO guideline_chunks (
			id, version_id, section_id, title, content, html, page_start, page_end,
			language, program_area, source_name, source_version, review_status,
			embedding_text, embedding
		)
		VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?::vector)
		ON CONFLICT (id) DO UPDATE SET
			version_id = EXCLUDED.version_id,
			section_id = EXCLUDED.section_id,
			title = EXCLUDED.title,
			content = EXCLUDED.content,
			html = EXCLUDED.html,
			page_start = EXCLUDED.page_start,
			page_end = EXCLUDED.page_end,
			language = EXCLUDED.language,
			program_area = EXCLUDED.program_area,
			source_name = EXCLUDED.source_name,
			source_version = EXCLUDED.source_version,
			review_status = EXCLUDED.review_status,
			embedding_text = EXCLUDED.embedding_text,
			embedding = EXCLUDED.embedding
		`,
		id,
		versionID,
		sectionID,
		title,
		content,
		html,
		pageStart,
		pageEnd,
		language,
		programArea,
		sourceName,
		sourceVersion,
		reviewStatus,
		content,
		seedVector(vectorSeed),
	).Error
}

func seedVector(seed int) string {
	values := make([]string, 1024)
	for i := range values {
		value := "0"
		switch {
		case i == seed:
			value = "1"
		case i == seed+1:
			value = "0.25"
		case i == seed+2:
			value = "0.1"
		}
		values[i] = value
	}
	return fmt.Sprintf("[%s]", strings.Join(values, ","))
}
