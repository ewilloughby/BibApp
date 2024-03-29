# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 2023_06_16_184533) do

  create_table "attachments", id: :integer, charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.integer "asset_id"
    t.string "asset_type"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "type"
    t.string "data_file_name"
    t.string "data_content_type"
    t.integer "data_file_size"
    t.datetime "data_updated_at"
  end

  create_table "authentications", id: :integer, charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.integer "user_id"
    t.string "provider"
    t.string "uid"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["uid"], name: "index_authentications_on_uid"
    t.index ["user_id"], name: "index_authentications_on_user_id"
  end

  create_table "bibapp_staff", charset: "utf8", force: :cascade do |t|
    t.string "login", limit: 12
    t.string "role", limit: 10
    t.string "first_name", limit: 15
    t.boolean "enabled", default: false
    t.bigint "user_id"
    t.index ["login"], name: "index_bibapp_staff_on_login", unique: true
    t.index ["user_id"], name: "index_bibapp_staff_on_user_id"
  end

  create_table "contributorship_states", id: :integer, charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.string "name"
  end

  create_table "contributorships", id: :integer, charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.integer "person_id"
    t.integer "work_id"
    t.integer "position"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "pen_name_id"
    t.boolean "highlight"
    t.integer "score"
    t.boolean "hide"
    t.integer "contributorship_state_id"
    t.string "role"
    t.index ["contributorship_state_id"], name: "index_contributorships_on_contributorship_state_id"
    t.index ["person_id"], name: "index_contributorships_on_person_id"
    t.index ["work_id", "person_id"], name: "work_person_join"
  end

  create_table "delayed_jobs", id: :integer, charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.integer "priority", default: 0
    t.integer "attempts", default: 0
    t.text "handler"
    t.text "last_error"
    t.datetime "run_at"
    t.datetime "locked_at"
    t.datetime "failed_at"
    t.string "locked_by"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "queue"
    t.integer "delayed_reference_id"
    t.string "delayed_reference_type"
    t.index ["delayed_reference_id"], name: "delayed_jobs_delayed_reference_id"
    t.index ["delayed_reference_type"], name: "delayed_jobs_delayed_reference_type"
  end

  create_table "external_system_uris", id: :integer, charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.integer "external_system_id"
    t.integer "work_id"
    t.text "uri"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "external_systems", id: :integer, charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.text "name"
    t.string "abbreviation"
    t.text "base_url"
    t.text "lookup_params"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "machine_name"
    t.index ["machine_name"], name: "external_system_machine_name"
  end

  create_table "groups", id: :integer, charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.string "name"
    t.string "url"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "description"
    t.boolean "hide"
    t.datetime "start_date"
    t.datetime "end_date"
    t.integer "parent_id"
    t.string "machine_name"
    t.string "sort_name"
    t.index ["machine_name"], name: "group_machine_name"
    t.index ["name"], name: "group_name", unique: true
  end

  create_table "identifiers", id: :integer, charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.string "name"
    t.string "type", default: "Unknown", null: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["name", "type"], name: "index_identifiers_on_name_and_type", unique: true
  end

  create_table "identifyings", id: :integer, charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.integer "identifier_id", null: false
    t.integer "identifiable_id", null: false
    t.string "identifiable_type", null: false
    t.integer "position"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["identifiable_id", "identifiable_type"], name: "index_identifyings_on_identifiable_id_and_identifiable_type"
    t.index ["identifier_id"], name: "index_identifyings_on_identifier_id"
  end

  create_table "imports", id: :integer, charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "person_id"
    t.string "state"
    t.text "works_added"
    t.text "import_errors", size: :long
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "keywordings", id: :integer, charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.integer "keyword_id"
    t.integer "work_id"
    t.integer "position"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["work_id", "keyword_id"], name: "work_keyword_join", unique: true
  end

  create_table "keywords", id: :integer, charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["name"], name: "keyword_name", unique: true
  end

  create_table "memberships", id: :integer, charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.integer "person_id"
    t.integer "group_id"
    t.string "title"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.integer "position"
    t.date "start_date"
    t.date "end_date"
    t.index ["person_id", "group_id"], name: "person_group_join"
  end

  create_table "name_strings", id: :integer, charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.binary "name", limit: 255
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "machine_name"
    t.boolean "cleaned", default: false
    t.index ["machine_name", "name"], name: "index_name_strings_on_machine_name_and_name", unique: true
    t.index ["name"], name: "author_name"
  end

  create_table "pen_names", id: :integer, charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.integer "name_string_id"
    t.integer "person_id"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["name_string_id", "person_id"], name: "author_person_join", unique: true
  end

  create_table "people", id: :integer, charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.integer "external_id"
    t.string "first_name"
    t.string "middle_name"
    t.string "last_name"
    t.string "prefix"
    t.string "suffix"
    t.string "image_url"
    t.string "phone"
    t.string "email"
    t.string "im"
    t.string "office_address_line_one"
    t.string "office_address_line_two"
    t.string "office_city"
    t.string "office_state"
    t.string "office_zip"
    t.text "research_focus"
    t.boolean "active"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "scoring_hash"
    t.string "machine_name"
    t.string "uid"
    t.string "display_name"
    t.text "postal_address"
    t.integer "user_id"
    t.date "start_date"
    t.date "end_date"
    t.index ["machine_name"], name: "person_machine_name"
    t.index ["user_id"], name: "index_people_on_user_id"
  end

  create_table "publications", id: :integer, charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.integer "sherpa_id"
    t.integer "publisher_id"
    t.integer "source_id"
    t.integer "authority_id"
    t.string "name"
    t.string "url"
    t.string "code"
    t.string "issn_isbn"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "place"
    t.string "machine_name"
    t.integer "initial_publisher_id"
    t.string "sort_name"
    t.index ["authority_id"], name: "fk_publication_authority_id"
    t.index ["issn_isbn"], name: "issn_isbn"
    t.index ["machine_name"], name: "publication_machine_name"
    t.index ["name"], name: "publication_name"
    t.index ["publisher_id"], name: "fk_publication_publisher_id"
  end

  create_table "publishers", id: :integer, charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.integer "sherpa_id"
    t.integer "publisher_source_id"
    t.integer "authority_id"
    t.boolean "publisher_copy"
    t.string "name"
    t.string "url"
    t.string "romeo_color"
    t.string "copyright_notice"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "machine_name"
    t.string "sort_name"
    t.index ["authority_id"], name: "fk_publisher_authority_id"
    t.index ["machine_name"], name: "publisher_machine_name"
  end

  create_table "roles", id: :integer, charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.string "name", limit: 40
    t.string "authorizable_type", limit: 30
    t.integer "authorizable_id"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "roles_users", id: false, charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.integer "user_id"
    t.integer "role_id"
  end

  create_table "sessions", id: :integer, charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.string "session_id", null: false
    t.text "data"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["session_id"], name: "index_sessions_on_session_id"
    t.index ["updated_at"], name: "index_sessions_on_updated_at"
  end

  create_table "staff_work_notes", charset: "utf8", force: :cascade do |t|
    t.integer "work_id"
    t.text "note"
  end

  create_table "taggings", id: :integer, charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.integer "tag_id"
    t.integer "taggable_id"
    t.string "taggable_type"
    t.datetime "created_at"
    t.integer "user_id"
    t.index ["tag_id"], name: "index_taggings_on_tag_id"
    t.index ["taggable_id", "taggable_type"], name: "index_taggings_on_taggable_id_and_taggable_type"
  end

  create_table "tags", id: :integer, charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.string "name"
    t.index ["name"], name: "tag_name", unique: true
  end

  create_table "tolk_locales", id: :integer, charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["name"], name: "index_tolk_locales_on_name", unique: true
  end

  create_table "tolk_phrases", id: :integer, charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.text "key"
    t.datetime "created_at"
    t.datetime "updated_at"
  end

  create_table "tolk_translations", id: :integer, charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.integer "phrase_id"
    t.integer "locale_id"
    t.text "text"
    t.text "previous_text"
    t.boolean "primary_updated", default: false
    t.datetime "created_at"
    t.datetime "updated_at"
    t.index ["phrase_id", "locale_id"], name: "index_tolk_translations_on_phrase_id_and_locale_id", unique: true
  end

  create_table "users", id: :integer, charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.string "login"
    t.string "email"
    t.string "encrypted_password"
    t.string "salt", limit: 40
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "remember_token"
    t.datetime "remember_token_expires_at"
    t.string "activation_code", limit: 40
    t.datetime "activated_at"
    t.string "default_locale"
    t.integer "failed_login_count"
    t.integer "sign_in_count"
    t.datetime "last_sign_in_at"
    t.datetime "current_sign_in_at"
    t.datetime "last_request_at"
    t.string "last_sign_in_ip"
    t.string "current_sign_in_ip"
    t.string "password_salt"
    t.string "persistence_token", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.datetime "locked_at"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["last_request_at"], name: "index_users_on_last_request_at"
  end

  create_table "work_name_strings", id: :integer, charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.integer "name_string_id"
    t.integer "work_id"
    t.integer "position"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.string "role"
    t.index ["work_id", "name_string_id", "role"], name: "work_name_string_role_join", unique: true
  end

  create_table "works", id: :integer, charset: "utf8", collation: "utf8_unicode_ci", force: :cascade do |t|
    t.string "type"
    t.text "title_primary"
    t.text "title_secondary"
    t.text "title_tertiary"
    t.text "affiliation"
    t.string "volume"
    t.string "issue"
    t.string "start_page"
    t.string "end_page"
    t.text "abstract"
    t.text "notes"
    t.text "links"
    t.integer "work_state_id"
    t.integer "work_archive_state_id"
    t.integer "publication_id"
    t.integer "publisher_id"
    t.datetime "archived_at"
    t.datetime "created_at"
    t.datetime "updated_at"
    t.text "original_data"
    t.integer "batch_index", default: 0
    t.text "scoring_hash"
    t.string "language"
    t.text "copyright_holder"
    t.boolean "peer_reviewed"
    t.string "machine_name", limit: 765
    t.string "publication_place"
    t.string "sponsor"
    t.string "date_range"
    t.string "identifier"
    t.string "medium"
    t.string "degree_level"
    t.string "discipline"
    t.string "instrumentation"
    t.text "admin_definable"
    t.text "user_definable"
    t.integer "authority_publication_id"
    t.integer "authority_publisher_id"
    t.integer "initial_publication_id"
    t.integer "initial_publisher_id"
    t.string "location"
    t.integer "publication_date_year"
    t.integer "publication_date_month"
    t.integer "publication_date_day"
    t.string "sort_name", limit: 765
    t.integer "import_job_id"
    t.index ["batch_index"], name: "batch_index"
    t.index ["machine_name"], name: "work_machine_name"
    t.index ["publication_id"], name: "fk_work_publication_id"
    t.index ["publisher_id"], name: "fk_work_publisher_id"
    t.index ["type"], name: "fk_work_type"
    t.index ["work_state_id"], name: "fk_work_state_id"
  end

end
