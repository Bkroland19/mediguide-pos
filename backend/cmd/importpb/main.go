package main

import (
	"context"
	"database/sql"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"log"
	"sort"
	"strconv"
	"strings"
	"time"
	"unicode"

	"mediguide/internal/config"

	"github.com/google/uuid"
	"gorm.io/datatypes"
	"gorm.io/driver/postgres"
	"gorm.io/gorm"
	_ "modernc.org/sqlite"
)

var importOrder = []string{
	"roles",
	"users",
	"settings",
	"languages",
	"regions",
	"health_sub_regions",
	"districts",
	"counties",
	"health_sub_districts",
	"subcounties",
	"parishes",
	"facility_levels",
	"ownership_types",
	"authorities",
	"health_facilities",
	"consultants",
	"ministry_directory",
	"drug_categories",
	"drug_tags",
	"drug_classes",
	"therapeutic_categories",
	"drugs",
	"guideline_categories",
	"guideline_tags",
	"abbreviations",
	"guideline_index",
	"calculators",
	"medical_guidelines",
	"emergency_protocols",
	"generic_pages",
	"faq_tags",
	"faqs",
	"documentation",
	"support_tickets",
	"support_ticket_replies",
	"notifications",
	"conversations",
	"messages",
	"notification_templates",
	"notification_campaigns",
	"reading_progress",
	"calculator_usage_logs",
	"guideline_usage_logs",
	"drug_usage_logs",
	"abbreviation_usage_logs",
	"consultant_usage_logs",
	"facility_usage_logs",
	"ai_usage_logs",
}

var importedTables = append(append([]string{}, importOrder...), "user_roles", "guideline_documents", "guideline_versions")

var idNamespace = uuid.MustParse("f8568f2f-8f4c-4f52-9fbe-6502c997fe26")

var validUserSpecializations = map[string]bool{
	"General Practice":   true,
	"Pediatrics":         true,
	"Internal Medicine":  true,
	"Surgery":            true,
	"Emergency Medicine": true,
	"Obstetrics":         true,
	"Psychiatry":         true,
	"Radiology":          true,
	"Anesthesia":         true,
	"Nursing":            true,
	"Pharmacy":           true,
	"Laboratory":         true,
	"Public Health":      true,
	"Other":              true,
}

type fieldDef struct {
	Name         string `json:"name"`
	Type         string `json:"type"`
	CollectionID string `json:"collectionId"`
	MaxSelect    int    `json:"maxSelect"`
}

type collectionMeta struct {
	ID     string
	Name   string
	Type   string
	Fields map[string]fieldDef
}

type targetColumn struct {
	Name       string
	DataType   string
	UDTName    string
	IsNullable bool
}

type schemaRow struct {
	TableName  string
	ColumnName string
	DataType   string
	UDTName    string
	IsNullable string
}

type collectionRow struct {
	ID     string
	Name   string
	Type   string
	Fields string
}

type rowInsert struct {
	SourceID string
	Values   map[string]any
}

type userRoleAssignment struct {
	UserID  uuid.UUID
	RoleKey string
}

type importer struct {
	source           *sql.DB
	target           *gorm.DB
	collections      map[string]collectionMeta
	collectionIDName map[string]string
	targetSchema     map[string]map[string]targetColumn
	canonicalSource  map[string]map[string]string
	sourceCounts     map[string]int
	importedCounts   map[string]int
	roleAssignments  []userRoleAssignment
}

func main() {
	var sqlitePath string
	var truncate bool
	flag.StringVar(&sqlitePath, "sqlite", "migrations/init_db/data.db", "path to PocketBase SQLite database")
	flag.BoolVar(&truncate, "truncate", true, "truncate imported legacy tables before loading")
	flag.Parse()

	cfg := config.Load()

	source, err := sql.Open("sqlite", fmt.Sprintf("file:%s?mode=ro&immutable=1", sqlitePath))
	if err != nil {
		log.Fatalf("open sqlite: %v", err)
	}
	defer source.Close()

	target, err := gorm.Open(postgres.Open(cfg.DatabaseURL), &gorm.Config{})
	if err != nil {
		log.Fatalf("open postgres: %v", err)
	}

	imp := &importer{
		source:           source,
		target:           target,
		collections:      map[string]collectionMeta{},
		collectionIDName: map[string]string{"_pb_users_auth_": "users"},
		targetSchema:     map[string]map[string]targetColumn{},
		canonicalSource:  map[string]map[string]string{},
		sourceCounts:     map[string]int{},
		importedCounts:   map[string]int{},
	}

	if err := imp.loadCollections(); err != nil {
		log.Fatalf("load collection metadata: %v", err)
	}
	if err := imp.loadTargetSchema(); err != nil {
		log.Fatalf("load target schema: %v", err)
	}

	if err := imp.target.Transaction(func(tx *gorm.DB) error {
		if truncate {
			if err := truncateImportedTables(tx); err != nil {
				return err
			}
		}

		for _, table := range importOrder {
			if err := imp.importTable(tx, table); err != nil {
				return fmt.Errorf("import %s: %w", table, err)
			}
		}
		if err := imp.insertUserRoles(tx); err != nil {
			return fmt.Errorf("insert user_roles: %w", err)
		}
		if err := imp.insertRolePermissions(tx); err != nil {
			return fmt.Errorf("insert role_permissions: %w", err)
		}
		return nil
	}); err != nil {
		log.Fatalf("import failed: %v", err)
	}

	imp.printSummary()
}

func truncateImportedTables(tx *gorm.DB) error {
	quoted := make([]string, 0, len(importedTables))
	for _, table := range importedTables {
		quoted = append(quoted, fmt.Sprintf(`"%s"`, table))
	}
	return tx.Exec("TRUNCATE TABLE " + strings.Join(quoted, ", ") + " CASCADE").Error
}

func (i *importer) loadCollections() error {
	var rows []collectionRow
	if err := i.target.Raw("SELECT 1").Error; err != nil {
		return err
	}

	query := `
SELECT id, name, type, fields
FROM _collections
WHERE type IN ('base', 'auth')
`
	srcRows, err := i.source.Query(query)
	if err != nil {
		return err
	}
	defer srcRows.Close()

	for srcRows.Next() {
		var row collectionRow
		if err := srcRows.Scan(&row.ID, &row.Name, &row.Type, &row.Fields); err != nil {
			return err
		}

		fields := []fieldDef{}
		if err := json.Unmarshal([]byte(row.Fields), &fields); err != nil {
			return fmt.Errorf("parse fields for %s: %w", row.Name, err)
		}

		meta := collectionMeta{
			ID:     row.ID,
			Name:   row.Name,
			Type:   row.Type,
			Fields: map[string]fieldDef{},
		}
		for _, field := range fields {
			meta.Fields[field.Name] = field
		}
		i.collections[row.Name] = meta
		i.collectionIDName[row.ID] = row.Name
		rows = append(rows, row)
	}

	return srcRows.Err()
}

func (i *importer) loadTargetSchema() error {
	var rows []schemaRow
	err := i.target.Raw(`
SELECT table_name, column_name, data_type, udt_name, is_nullable
FROM information_schema.columns
WHERE table_schema = 'public'
`).Scan(&rows).Error
	if err != nil {
		return err
	}

	for _, row := range rows {
		if _, ok := i.targetSchema[row.TableName]; !ok {
			i.targetSchema[row.TableName] = map[string]targetColumn{}
		}
		i.targetSchema[row.TableName][row.ColumnName] = targetColumn{
			Name:       row.ColumnName,
			DataType:   row.DataType,
			UDTName:    row.UDTName,
			IsNullable: row.IsNullable == "YES",
		}
	}
	return nil
}

func (i *importer) importTable(tx *gorm.DB, table string) error {
	meta, ok := i.collections[table]
	if !ok {
		return fmt.Errorf("missing collection metadata")
	}
	if _, ok := i.targetSchema[table]; !ok {
		return fmt.Errorf("target table missing")
	}

	rows, err := i.readSourceRows(table)
	if err != nil {
		return err
	}
	rows = i.dedupeSourceRows(table, rows)
	i.sourceCounts[table] = len(rows)

	inserts := make([]rowInsert, 0, len(rows))
	for _, row := range rows {
		insert, err := i.buildInsert(table, meta, row)
		if err != nil {
			return fmt.Errorf("build row %s: %w", stringify(row["id"]), err)
		}
		inserts = append(inserts, insert)
	}

	inserts = i.sortSelfReferentialRows(table, meta, inserts)

	inserted, err := i.insertRows(tx, table, inserts)
	if err != nil {
		return err
	}
	i.importedCounts[table] = inserted

	if table == "medical_guidelines" {
		if err := i.insertSyntheticGuidelineDocuments(tx, rows); err != nil {
			return err
		}
	}
	return nil
}

func (i *importer) insertSyntheticGuidelineDocuments(tx *gorm.DB, rows []map[string]any) error {
	for _, row := range rows {
		sourceID := strings.TrimSpace(stringify(row["id"]))
		if sourceID == "" {
			continue
		}

		documentID := deterministicUUID("guideline_documents", sourceID)
		versionID := deterministicUUID("guideline_versions", sourceID)
		createdAt := parseTimestampOrZero(stringify(row["created"]))
		updatedAt := parseTimestampOrZero(stringify(row["updated"]))

		title := strings.TrimSpace(stringify(row["condition_name"]))
		if title == "" {
			title = "Imported Guideline"
		}

		description := firstNonEmpty(
			strings.TrimSpace(stringify(row["definition"])),
			strings.TrimSpace(stringify(row["target_population"])),
		)

		documentValues := map[string]any{
			"id":          documentID,
			"title":       title,
			"language":    "en",
			"description": description,
			"created_at":  createdAt,
			"updated_at":  updatedAt,
		}
		if programArea := strings.TrimSpace(stringify(row["target_population"])); programArea != "" {
			documentValues["program_area"] = programArea
		}

		if err := tx.Table("guideline_documents").Create(documentValues).Error; err != nil {
			return fmt.Errorf("insert guideline_document for %s: %w", sourceID, err)
		}

		versionValues := map[string]any{
			"id":          versionID,
			"document_id": documentID,
			"version":     firstNonEmpty(strings.TrimSpace(stringify(row["version"])), "1.0"),
			"status":      normalizeGuidelineVersionStatus(row),
			"created_at":  createdAt,
			"updated_at":  updatedAt,
		}
		if publishedAt := strings.TrimSpace(stringify(row["updated"])); publishedAt != "" {
			versionValues["publication_date"] = publishedAt
		}

		if err := tx.Table("guideline_versions").Create(versionValues).Error; err != nil {
			return fmt.Errorf("insert guideline_version for %s: %w", sourceID, err)
		}

		if err := tx.Table("guideline_documents").Where("id = ?", documentID).Update("current_version_id", versionID).Error; err != nil {
			return fmt.Errorf("update guideline_document current_version_id for %s: %w", sourceID, err)
		}
	}

	return nil
}

func (i *importer) readSourceRows(table string) ([]map[string]any, error) {
	query := fmt.Sprintf(`SELECT * FROM "%s"`, table)
	rows, err := i.source.Query(query)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	columns, err := rows.Columns()
	if err != nil {
		return nil, err
	}

	var result []map[string]any
	for rows.Next() {
		values := make([]any, len(columns))
		scan := make([]any, len(columns))
		for idx := range scan {
			scan[idx] = &values[idx]
		}
		if err := rows.Scan(scan...); err != nil {
			return nil, err
		}

		row := make(map[string]any, len(columns))
		for idx, column := range columns {
			row[column] = normalizeSQLiteValue(values[idx])
		}
		result = append(result, row)
	}

	return result, rows.Err()
}

func normalizeSQLiteValue(value any) any {
	switch typed := value.(type) {
	case []byte:
		return string(typed)
	default:
		return typed
	}
}

func (i *importer) buildInsert(table string, meta collectionMeta, row map[string]any) (rowInsert, error) {
	sourceID := stringify(row["id"])
	if sourceID == "" {
		return rowInsert{}, errors.New("missing id")
	}

	values := map[string]any{
		"id": i.mappedUUID(table, sourceID),
	}

	for fieldName, rawValue := range row {
		if fieldName == "id" || fieldName == "password" || fieldName == "tokenKey" {
			continue
		}

		fieldMeta, ok := meta.Fields[fieldName]
		if !ok {
			fieldMeta = fieldDef{Name: fieldName, Type: inferFieldType(rawValue)}
		}

		columnName := i.resolveTargetColumn(table, fieldName, fieldMeta)
		if columnName == "" {
			continue
		}

		value, keep, err := i.transformValue(table, fieldName, columnName, fieldMeta, rawValue)
		if err != nil {
			return rowInsert{}, err
		}
		if keep {
			values[columnName] = value
		}
	}

	if err := i.applyTableSpecificTransforms(table, row, values); err != nil {
		return rowInsert{}, err
	}

	return rowInsert{SourceID: sourceID, Values: values}, nil
}

func inferFieldType(value any) string {
	switch value.(type) {
	case bool:
		return "bool"
	case int64, float64:
		return "number"
	default:
		return "text"
	}
}

func (i *importer) resolveTargetColumn(table, fieldName string, fieldMeta fieldDef) string {
	schema := i.targetSchema[table]
	if schema == nil {
		return ""
	}

	if override, ok := columnOverrides[table][fieldName]; ok {
		if _, exists := schema[override]; exists {
			return override
		}
	}

	snake := toSnakeCase(fieldName)
	candidates := []string{}

	switch fieldName {
	case "created":
		candidates = append(candidates, "created_at")
	case "updated":
		candidates = append(candidates, "updated_at")
	}

	candidates = append(candidates, snake)

	switch fieldMeta.Type {
	case "relation":
		if fieldMeta.MaxSelect > 1 {
			candidates = append(candidates, snake+"_json")
		} else {
			candidates = append(candidates, snake+"_id")
			if i.relatedTable(fieldMeta) == "users" {
				candidates = append(candidates, snake+"_user_id")
			}
		}
	case "json", "file":
		candidates = append(candidates, snake+"_json")
	}

	if fieldMeta.Type == "file" && snake == "avatar" {
		candidates = append(candidates, "avatar_json", "avatar")
	}

	for _, candidate := range dedupeStrings(candidates) {
		if _, ok := schema[candidate]; ok {
			return candidate
		}
	}

	return ""
}

func (i *importer) transformValue(table, fieldName, columnName string, fieldMeta fieldDef, rawValue any) (any, bool, error) {
	schema := i.targetSchema[table][columnName]

	if fieldName == "guideline_id" && (table == "reading_progress" || table == "guideline_usage_logs") {
		raw := stringify(rawValue)
		if raw == "" {
			return nil, false, nil
		}
		return i.mappedUUID("guideline_documents", raw), true, nil
	}

	switch fieldMeta.Type {
	case "relation":
		return i.transformRelationValue(table, fieldName, schema, fieldMeta, rawValue)
	case "json":
		return i.transformJSONValue(rawValue, false, "")
	case "file":
		return i.transformFileValue(table, fieldName, rawValue)
	}

	switch schema.UDTName {
	case "uuid":
		raw := stringify(rawValue)
		if raw == "" {
			return nil, false, nil
		}
		return i.mappedUUID(i.relatedTable(fieldMeta), raw), true, nil
	case "jsonb":
		return i.transformJSONValue(rawValue, false, "")
	case "bool":
		return asBool(rawValue), true, nil
	case "int4", "int8":
		number, ok := asInt(rawValue)
		if !ok {
			return nil, false, nil
		}
		return number, true, nil
	case "float8":
		number, ok := asFloat(rawValue)
		if !ok {
			return nil, false, nil
		}
		return number, true, nil
	case "timestamptz":
		text := stringify(rawValue)
		if text == "" {
			return nil, false, nil
		}
		parsed, err := parseTimestamp(text)
		if err != nil {
			return nil, false, nil
		}
		return parsed, true, nil
	default:
		text := stringify(rawValue)
		if text == "" {
			return nil, false, nil
		}
		return text, true, nil
	}
}

func (i *importer) transformRelationValue(table, fieldName string, schema targetColumn, fieldMeta fieldDef, rawValue any) (any, bool, error) {
	relatedTable := i.relatedTable(fieldMeta)
	if relatedTable == "" {
		return nil, false, nil
	}

	if fieldMeta.MaxSelect > 1 || schema.UDTName == "jsonb" {
		ids := parseStringArray(rawValue)
		mapped := make([]string, 0, len(ids))
		for _, id := range ids {
			if id == "" {
				continue
			}
			mapped = append(mapped, i.mappedUUID(relatedTable, id).String())
		}
		if len(mapped) == 0 {
			return nil, false, nil
		}
		jsonValue, err := marshalJSON(mapped)
		if err != nil {
			return nil, false, err
		}
		return jsonValue, true, nil
	}

	raw := stringify(rawValue)
	if raw == "" {
		return nil, false, nil
	}
	return i.mappedUUID(relatedTable, raw), true, nil
}

func (i *importer) transformJSONValue(rawValue any, remapIDs bool, relatedTable string) (any, bool, error) {
	text := stringify(rawValue)
	if text == "" {
		return nil, false, nil
	}

	var payload any
	if err := json.Unmarshal([]byte(text), &payload); err != nil {
		return nil, false, err
	}

	if remapIDs && relatedTable != "" {
		if ids, ok := payload.([]any); ok {
			mapped := make([]string, 0, len(ids))
			for _, item := range ids {
				raw := stringify(item)
				if raw == "" {
					continue
				}
				mapped = append(mapped, i.mappedUUID(relatedTable, raw).String())
			}
			payload = mapped
		}
	}

	jsonValue, err := marshalJSON(payload)
	if err != nil {
		return nil, false, err
	}
	return jsonValue, true, nil
}

func (i *importer) transformFileValue(table, fieldName string, rawValue any) (any, bool, error) {
	raw := stringify(rawValue)
	if raw == "" {
		return nil, false, nil
	}

	payload := map[string]any{
		"name": raw,
		"path": raw,
	}

	if table == "calculators" && fieldName == "appFile" {
		payload["path"] = raw
	}

	jsonValue, err := marshalJSON(payload)
	if err != nil {
		return nil, false, err
	}
	return jsonValue, true, nil
}

func (i *importer) relatedTable(fieldMeta fieldDef) string {
	if fieldMeta.CollectionID == "" {
		return ""
	}
	return i.collectionIDName[fieldMeta.CollectionID]
}

func (i *importer) applyTableSpecificTransforms(table string, row map[string]any, values map[string]any) error {
	switch table {
	case "users":
		values["password_hash"] = stringify(row["password"])

		status := normalizeUserStatus(stringify(row["status"]))
		if status != "" {
			values["status"] = status
			values["is_active"] = status == "active"
		}

		if preferred := normalizeUserPreferredLanguage(stringify(row["preferredLanguage"])); preferred != "" {
			values["preferred_language"] = preferred
		}

		if specialization := strings.TrimSpace(stringify(row["specialization"])); specialization != "" {
			values["specialization"] = specialization
			if validUserSpecializations[specialization] {
				payload, err := marshalJSON([]string{specialization})
				if err != nil {
					return err
				}
				values["specialization_json"] = payload
			}
		}

		roleKey := strings.TrimSpace(stringify(row["role"]))
		if roleKey != "" {
			i.roleAssignments = append(i.roleAssignments, userRoleAssignment{
				UserID:  values["id"].(uuid.UUID),
				RoleKey: roleKey,
			})
		}
	case "roles":
		if key := strings.TrimSpace(stringify(row["key"])); key != "" {
			values["role_key"] = key
		}
		if permissions := strings.TrimSpace(stringify(row["permissions"])); permissions != "" {
			values["permissions_json"] = datatypes.JSON([]byte(permissions))
		}
		values["is_active"] = asBool(row["isActive"])
	case "consultants":
		if qualification := normalizeConsultantQualification(row["qualifications"]); qualification != "" {
			values["qualifications"] = qualification
		} else {
			delete(values, "qualifications")
		}
		if consultationType := normalizeSingleSelect(row["consultationTypes"]); consultationType != "" {
			values["consultation_types"] = consultationType
		}
		if status := normalizeConsultantStatus(stringify(row["status"])); status != "" {
			values["status"] = status
		}
	case "drugs":
		if route := normalizeSingleSelect(row["route_of_administration"]); route != "" {
			values["route_of_administration"] = route
		}
	case "languages":
		if _, ok := values["translations_json"]; !ok {
			if translations := strings.TrimSpace(stringify(row["translations"])); translations != "" {
				values["translations_json"] = datatypes.JSON([]byte(translations))
			}
		}
	case "settings":
		if value := strings.TrimSpace(stringify(row["value"])); value != "" {
			values["value_json"] = datatypes.JSON([]byte(value))
		}
	}

	normalizeTimestamps(values)
	return nil
}

func normalizeTimestamps(values map[string]any) {
	for _, field := range []string{"created_at", "updated_at"} {
		raw, ok := values[field]
		if !ok {
			continue
		}
		text, ok := raw.(string)
		if !ok || strings.TrimSpace(text) == "" {
			continue
		}
		parsed, err := parseTimestamp(text)
		if err != nil {
			delete(values, field)
			continue
		}
		values[field] = parsed
	}
}

func (i *importer) sortSelfReferentialRows(table string, meta collectionMeta, inserts []rowInsert) []rowInsert {
	selfRefs := []string{}
	for _, field := range meta.Fields {
		if field.Type == "relation" && field.MaxSelect <= 1 && i.relatedTable(field) == table {
			column := i.resolveTargetColumn(table, field.Name, field)
			if strings.HasSuffix(column, "_id") {
				selfRefs = append(selfRefs, column)
			}
		}
	}
	if len(selfRefs) == 0 {
		return inserts
	}

	sorted := append([]rowInsert{}, inserts...)
	sort.SliceStable(sorted, func(left, right int) bool {
		return rowDepth(sorted[left], selfRefs) < rowDepth(sorted[right], selfRefs)
	})
	return sorted
}

func rowDepth(row rowInsert, selfRefs []string) int {
	for _, field := range selfRefs {
		if value, ok := row.Values[field]; ok && value != nil {
			return 1
		}
	}
	return 0
}

func (i *importer) insertRows(tx *gorm.DB, table string, rows []rowInsert) (int, error) {
	pending := append([]rowInsert{}, rows...)
	inserted := 0

	for len(pending) > 0 {
		next := make([]rowInsert, 0)
		progress := 0

		for _, row := range pending {
			if err := tx.WithContext(context.Background()).Table(table).Create(row.Values).Error; err != nil {
				if isForeignKeyError(err) {
					next = append(next, row)
					continue
				}
				return inserted, fmt.Errorf("insert %s row %s: %w", table, row.SourceID, err)
			}
			inserted++
			progress++
		}

		if progress == 0 {
			return inserted, fmt.Errorf("stalled inserting %s; unresolved dependencies on %d rows", table, len(next))
		}

		pending = next
	}

	return inserted, nil
}

func isForeignKeyError(err error) bool {
	return strings.Contains(strings.ToLower(err.Error()), "violates foreign key constraint")
}

func (i *importer) insertUserRoles(tx *gorm.DB) error {
	var roles []struct {
		ID      uuid.UUID
		RoleKey *string
	}
	if err := tx.Table("roles").Select("id, role_key").Scan(&roles).Error; err != nil {
		return err
	}

	roleByKey := map[string]uuid.UUID{}
	for _, role := range roles {
		if role.RoleKey != nil && strings.TrimSpace(*role.RoleKey) != "" {
			roleByKey[strings.TrimSpace(*role.RoleKey)] = role.ID
		}
	}

	inserted := map[string]bool{}
	for _, assignment := range i.roleAssignments {
		roleID, ok := roleByKey[assignment.RoleKey]
		if !ok {
			continue
		}
		key := assignment.UserID.String() + ":" + roleID.String()
		if inserted[key] {
			continue
		}
		if err := tx.Table("user_roles").Create(map[string]any{
			"user_id": assignment.UserID,
			"role_id": roleID,
		}).Error; err != nil {
			return err
		}
		inserted[key] = true
	}

	return nil
}

func (i *importer) insertRolePermissions(tx *gorm.DB) error {
	var permissions []struct {
		ID   uuid.UUID
		Code string
	}
	if err := tx.Table("permissions").Select("id, code").Scan(&permissions).Error; err != nil {
		return err
	}

	permissionByCode := map[string]uuid.UUID{}
	for _, permission := range permissions {
		permissionByCode[permission.Code] = permission.ID
	}

	var roles []struct {
		ID              uuid.UUID
		RoleKey         *string
		PermissionsJSON string
	}
	if err := tx.Table("roles").Select("id, role_key, permissions_json").Scan(&roles).Error; err != nil {
		return err
	}

	inserted := map[string]bool{}
	for _, role := range roles {
		roleKey := ""
		if role.RoleKey != nil {
			roleKey = strings.TrimSpace(*role.RoleKey)
		}
		for _, code := range deriveBackendPermissions(roleKey, role.PermissionsJSON) {
			permissionID, ok := permissionByCode[code]
			if !ok {
				continue
			}
			key := role.ID.String() + ":" + permissionID.String()
			if inserted[key] {
				continue
			}
			if err := tx.Table("role_permissions").Create(map[string]any{
				"role_id":       role.ID,
				"permission_id": permissionID,
			}).Error; err != nil {
				return err
			}
			inserted[key] = true
		}
	}

	return nil
}

func deriveBackendPermissions(roleKey, permissionsJSON string) []string {
	switch roleKey {
	case "super_admin", "admin":
		return []string{"admin.all"}
	case "content_manager", "reviewer":
		return []string{
			"guideline.read",
			"guideline.write",
			"guideline.publish",
			"protocol.read",
			"protocol.write",
			"chat.ask",
			"sync.read",
		}
	case "healthcare_provider":
		return []string{
			"guideline.read",
			"protocol.read",
			"chat.ask",
			"sync.read",
		}
	case "observer":
		return []string{
			"guideline.read",
			"protocol.read",
			"sync.read",
		}
	}

	var payload map[string]map[string][]string
	if err := json.Unmarshal([]byte(permissionsJSON), &payload); err != nil {
		return nil
	}

	perms := map[string]bool{}
	for resource, actions := range payload {
		_, hasReadAny := actions["read:any"]
		_, hasReadOwn := actions["read:own"]
		_, hasCreateAny := actions["create:any"]
		_, hasUpdateAny := actions["update:any"]
		_, hasDeleteAny := actions["delete:any"]

		switch resource {
		case "content":
			if hasReadAny || hasReadOwn {
				perms["guideline.read"] = true
				perms["protocol.read"] = true
			}
			if hasCreateAny || hasUpdateAny || hasDeleteAny {
				perms["guideline.write"] = true
				perms["protocol.write"] = true
			}
		case "reports":
			if hasReadAny || hasReadOwn {
				perms["sync.read"] = true
			}
		}
	}

	if len(perms) == 0 {
		return nil
	}

	result := make([]string, 0, len(perms))
	for code := range perms {
		result = append(result, code)
	}
	sort.Strings(result)
	return result
}

func (i *importer) printSummary() {
	fmt.Println("PocketBase to Postgres import summary:")
	for _, table := range importOrder {
		fmt.Printf("  %-24s source=%-4d imported=%-4d\n", table, i.sourceCounts[table], i.importedCounts[table])
	}
}

func deterministicUUID(table, sourceID string) uuid.UUID {
	return uuid.NewSHA1(idNamespace, []byte(table+":"+sourceID))
}

func (i *importer) mappedUUID(table, sourceID string) uuid.UUID {
	return deterministicUUID(table, i.canonicalSourceID(table, sourceID))
}

func (i *importer) canonicalSourceID(table, sourceID string) string {
	canonical := strings.TrimSpace(sourceID)
	if canonical == "" {
		return canonical
	}
	if aliases, ok := i.canonicalSource[table]; ok {
		if mapped := strings.TrimSpace(aliases[canonical]); mapped != "" {
			return mapped
		}
	}
	return canonical
}

func marshalJSON(value any) (datatypes.JSON, error) {
	data, err := json.Marshal(value)
	if err != nil {
		return nil, err
	}
	return datatypes.JSON(data), nil
}

func parseTimestamp(value string) (time.Time, error) {
	layouts := []string{
		time.RFC3339Nano,
		"2006-01-02 15:04:05.999Z",
		"2006-01-02 15:04:05Z",
		"2006-01-02 15:04:05.999999Z",
		"2006-01-02",
	}
	for _, layout := range layouts {
		if parsed, err := time.Parse(layout, value); err == nil {
			return parsed, nil
		}
	}
	return time.Time{}, fmt.Errorf("unsupported timestamp %q", value)
}

func parseTimestampOrZero(value string) time.Time {
	parsed, err := parseTimestamp(strings.TrimSpace(value))
	if err != nil {
		return time.Time{}
	}
	return parsed
}

func firstNonEmpty(values ...string) string {
	for _, value := range values {
		if trimmed := strings.TrimSpace(value); trimmed != "" {
			return trimmed
		}
	}
	return ""
}

func normalizeGuidelineVersionStatus(row map[string]any) string {
	if asBool(row["is_published"]) {
		return "published"
	}

	switch strings.TrimSpace(strings.ToLower(stringify(row["status"]))) {
	case "published":
		return "published"
	default:
		return "draft"
	}
}

func normalizeUserStatus(value string) string {
	switch strings.TrimSpace(value) {
	case "pendingActivation":
		return "pending_activation"
	default:
		return strings.TrimSpace(value)
	}
}

func normalizeUserPreferredLanguage(value string) string {
	switch strings.TrimSpace(strings.ToLower(value)) {
	case "":
		return ""
	case "english":
		return "English"
	case "french":
		return "French"
	case "spanish":
		return "Spanish"
	case "portuguese":
		return "Portuguese"
	case "arabic":
		return "Arabic"
	case "swahili":
		return "Swahili"
	case "amharic":
		return "Amharic"
	default:
		return strings.TrimSpace(value)
	}
}

func normalizeConsultantStatus(value string) string {
	switch strings.TrimSpace(value) {
	case "pendingApproval":
		return "pending_approval"
	default:
		return strings.TrimSpace(value)
	}
}

func normalizeConsultantQualification(value any) string {
	first := normalizeSingleSelect(value)
	switch first {
	case "DO_DEGREE":
		return "DO"
	default:
		return first
	}
}

func normalizeSingleSelect(value any) string {
	if text, ok := value.(string); ok {
		trimmed := strings.TrimSpace(text)
		if strings.HasPrefix(trimmed, "[") {
			items := parseStringArray(trimmed)
			if len(items) == 0 {
				return ""
			}
			return items[0]
		}
	}

	items := parseStringArray(value)
	if len(items) > 0 {
		return items[0]
	}
	return strings.TrimSpace(stringify(value))
}

func parseStringArray(value any) []string {
	switch typed := value.(type) {
	case nil:
		return nil
	case string:
		text := strings.TrimSpace(typed)
		if text == "" {
			return nil
		}
		if strings.HasPrefix(text, "[") {
			var items []string
			if err := json.Unmarshal([]byte(text), &items); err == nil {
				return compactStrings(items)
			}
		}
		return []string{text}
	case []string:
		return compactStrings(typed)
	case []any:
		out := make([]string, 0, len(typed))
		for _, item := range typed {
			if raw := strings.TrimSpace(stringify(item)); raw != "" {
				out = append(out, raw)
			}
		}
		return out
	default:
		text := strings.TrimSpace(stringify(value))
		if text == "" {
			return nil
		}
		return []string{text}
	}
}

func compactStrings(values []string) []string {
	out := make([]string, 0, len(values))
	for _, value := range values {
		if trimmed := strings.TrimSpace(value); trimmed != "" {
			out = append(out, trimmed)
		}
	}
	return out
}

func stringify(value any) string {
	switch typed := value.(type) {
	case nil:
		return ""
	case string:
		return typed
	case []byte:
		return string(typed)
	case json.RawMessage:
		return string(typed)
	case fmt.Stringer:
		return typed.String()
	case int64:
		return strconv.FormatInt(typed, 10)
	case int:
		return strconv.Itoa(typed)
	case float64:
		return strconv.FormatFloat(typed, 'f', -1, 64)
	case bool:
		if typed {
			return "true"
		}
		return "false"
	default:
		return fmt.Sprintf("%v", typed)
	}
}

func asBool(value any) bool {
	switch typed := value.(type) {
	case bool:
		return typed
	case int64:
		return typed != 0
	case float64:
		return typed != 0
	default:
		text := strings.TrimSpace(strings.ToLower(stringify(value)))
		return text == "true" || text == "1"
	}
}

func asInt(value any) (int64, bool) {
	switch typed := value.(type) {
	case int64:
		return typed, true
	case int:
		return int64(typed), true
	case float64:
		return int64(typed), true
	default:
		text := strings.TrimSpace(stringify(value))
		if text == "" {
			return 0, false
		}
		number, err := strconv.ParseInt(strings.Split(text, ".")[0], 10, 64)
		if err != nil {
			return 0, false
		}
		return number, true
	}
}

func asFloat(value any) (float64, bool) {
	switch typed := value.(type) {
	case float64:
		return typed, true
	case int64:
		return float64(typed), true
	case int:
		return float64(typed), true
	default:
		text := strings.TrimSpace(stringify(value))
		if text == "" {
			return 0, false
		}
		number, err := strconv.ParseFloat(text, 64)
		if err != nil {
			return 0, false
		}
		return number, true
	}
}

func toSnakeCase(value string) string {
	var builder strings.Builder
	for idx, r := range value {
		if unicode.IsUpper(r) {
			if idx > 0 {
				builder.WriteByte('_')
			}
			builder.WriteRune(unicode.ToLower(r))
			continue
		}
		builder.WriteRune(r)
	}
	return builder.String()
}

func dedupeStrings(values []string) []string {
	seen := map[string]bool{}
	out := make([]string, 0, len(values))
	for _, value := range values {
		if value == "" || seen[value] {
			continue
		}
		seen[value] = true
		out = append(out, value)
	}
	return out
}

func (i *importer) dedupeSourceRows(table string, rows []map[string]any) []map[string]any {
	switch table {
	case "abbreviations":
		deduped, aliases := dedupeByNewest(rows, "abbreviation")
		i.canonicalSource[table] = aliases
		return deduped
	default:
		return rows
	}
}

func dedupeByNewest(rows []map[string]any, keyField string) ([]map[string]any, map[string]string) {
	type keyedRow struct {
		row       map[string]any
		updatedAt time.Time
	}

	latest := map[string]keyedRow{}
	order := []string{}
	aliases := map[string]string{}

	for _, row := range rows {
		key := strings.TrimSpace(stringify(row[keyField]))
		if key == "" {
			continue
		}

		updatedAt, _ := parseTimestamp(strings.TrimSpace(stringify(row["updated"])))
		current, exists := latest[key]
		sourceID := strings.TrimSpace(stringify(row["id"]))
		if !exists {
			latest[key] = keyedRow{row: row, updatedAt: updatedAt}
			order = append(order, key)
			if sourceID != "" {
				aliases[sourceID] = sourceID
			}
			continue
		}
		if updatedAt.After(current.updatedAt) {
			currentID := strings.TrimSpace(stringify(current.row["id"]))
			if currentID != "" && sourceID != "" {
				aliases[currentID] = sourceID
			}
			latest[key] = keyedRow{row: row, updatedAt: updatedAt}
			aliases[sourceID] = sourceID
			continue
		}
		if currentID := strings.TrimSpace(stringify(current.row["id"])); currentID != "" && sourceID != "" {
			aliases[sourceID] = currentID
		}
	}

	out := make([]map[string]any, 0, len(latest))
	for _, key := range order {
		out = append(out, latest[key].row)
	}
	return out, aliases
}

var columnOverrides = map[string]map[string]string{
	"roles": {
		"key":         "role_key",
		"permissions": "permissions_json",
		"isActive":    "is_active",
	},
	"settings": {
		"value": "value_json",
	},
	"languages": {
		"translations": "translations_json",
	},
	"generic_pages": {
		"content": "content_json",
	},
	"users": {
		"preferredLanguage": "preferred_language",
		"alternativePhone":  "alternative_phone",
		"postalCode":        "postal_code",
		"licenseNumber":     "license_number",
		"jobTitle":          "job_title",
	},
	"consultants": {
		"profilePicture":     "profile_picture_json",
		"alternativePhone":   "alternative_phone",
		"licenseNumber":      "license_number",
		"yearsOfExperience":  "years_of_experience",
		"postalCode":         "postal_code",
		"preferredLanguage":  "preferred_language",
		"consultationTypes":  "consultation_types",
		"isVerified":         "is_verified",
		"totalConsultations": "total_consultations",
	},
	"calculators": {
		"appFile":         "app_file_json",
		"backgroundColor": "background_color",
		"addedBy":         "added_by_user_id",
		"usageCount":      "usage_count",
	},
	"medical_guidelines": {
		"index_item": "index_item_id",
		"usageCount": "usage_count",
		"categories": "categories_json",
		"tags":       "tags_json",
	},
	"drugs": {
		"drug_class":           "drug_class_id",
		"therapeutic_category": "therapeutic_category_id",
		"categories":           "categories_json",
		"tags":                 "tags_json",
	},
	"abbreviations": {
		"category": "category_id",
	},
	"guideline_categories": {
		"parent_category": "parent_category_id",
	},
	"guideline_index": {
		"parent":      "parent_id",
		"hasChildren": "has_children",
		"sortOrder":   "sort_order",
	},
	"faqs": {
		"author":       "author_id",
		"reviewer":     "reviewer_id",
		"tags":         "tags_json",
		"related_faqs": "related_faqs_json",
	},
	"reading_progress": {
		"guideline_id": "guideline_document_id",
	},
	"guideline_usage_logs": {
		"guideline_id": "guideline_document_id",
	},
}
