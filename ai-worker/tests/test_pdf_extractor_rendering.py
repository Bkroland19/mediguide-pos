from app.document_processing.pdf_extractor import (
    _clean_table_rows,
    _is_noise_line,
    _render_table_cell_content,
    _render_table_html,
    _section_html,
)


def test_section_html_renders_management_table_with_header_styling():
    html = _section_html(
        "Benign Prostatic Hyperplasia",
        2,
        "\n".join(
            [
                "Management",
                "TREATMENT",
                "LOC",
                " Treat with antibiotics if infection present",
                "HC2",
                " Surgical management if severe symptoms",
                "RR",
            ]
        ),
    )

    assert "<table" in html
    assert "TREATMENT" in html
    assert "LOC" in html
    assert "background:#dbe5f1" in html
    assert "Treat with antibiotics if infection present" in html
    assert "Surgical management if severe symptoms" in html
    assert "HC2" in html
    assert "RR" in html


def test_section_html_renders_bullets_as_list_items():
    html = _section_html(
        "Investigations",
        2,
        "\n".join(
            [
                "Investigations",
                " Urine analysis (blood, leucocytes)",
                " Renal function",
                " Abdominal ultrasound",
            ]
        ),
    )

    assert "<ul>" in html
    assert html.count("<li>") == 3
    assert "Urine analysis (blood, leucocytes)" in html


def test_clean_table_rows_discards_empty_rows():
    rows = _clean_table_rows(
        [
            ["", "", ""],
            ["TREATMENT", "LOC", ""],
            ["Treat infection", "HC2", None],
        ]
    )

    assert rows == [
        ["TREATMENT", "LOC", ""],
        ["Treat infection", "HC2", ""],
    ]


def test_render_table_html_preserves_untitled_multi_column_tables():
    html = _render_table_html(
        [
            ["DRUG", "DOSE", "ROUTE"],
            ["Diazepam", "10 mg", "IV"],
            ["Paracetamol", "1 g", "PO"],
        ],
        title=None,
    )

    assert "<table" in html
    assert "<caption" not in html
    assert "background:#dbe5f1" in html
    assert "DRUG" in html
    assert "Diazepam" in html


def test_render_table_html_skips_single_column_noise_tables():
    html = _render_table_html(
        [
            ["The Seven Steps in a Primary Care Consultation"],
            ["01 Greet 02 Look 03 Listen 04 Examine 05 Suspect diagnosis"],
        ],
        title=None,
    )

    assert html == ""


def test_section_html_does_not_promote_bullet_glyphs_to_headings():
    html = _section_html(
        "Chronic Care",
        3,
        "\n".join(
            [
                "~ Health workers are faced with an increasing number of chronic diseases",
                "~ Communication is even more important",
            ]
        ),
    )

    assert "<h4>~</h4>" not in html
    assert html.count("<li>") == 2


def test_is_noise_line_ignores_page_markers():
    assert _is_noise_line("LIII")
    assert _is_noise_line("465")


def test_render_table_cell_content_preserves_bullet_lists():
    html = _render_table_cell_content(
        "~ Accurate diagnosis of the condition\n~ Selection of the most appropriate medicine"
    )

    assert "<ul>" in html
    assert "Accurate diagnosis of the condition" in html
    assert "Selection of the most appropriate medicine" in html


def test_render_table_cell_content_reconstructs_inline_mini_table():
    html = _render_table_cell_content(
        "\n".join(
            [
                "Age (Months) <4 4-12 13-24 25-60",
                "Weight (Kg) <6 6-9.9 10-11.9 12-19",
                "ORS (Ml) 200-400 400-700 700-900 900-1400",
                "- Only use child's age if weight is not known",
            ]
        )
    )

    assert html.count("<table") >= 1
    assert "Age (Months)" in html
    assert "700-900" in html
    assert "Only use child&#x27;s age if weight is not known" in html
