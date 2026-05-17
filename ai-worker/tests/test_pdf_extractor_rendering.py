from app.document_processing.pdf_extractor import _clean_table_rows, _section_html


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
