import os
import re

from openapi_spec_validator import validate

from app.api_docs import markdown, spec

DOC_ROUTES = {"/api/openapi.json", "/api/docs", "/api/docs/", "/api/docs/files/<path:filename>"}


def _app_routes(app):
    """(path in OpenAPI form, method) for every /api route in the app."""
    found = set()
    for rule in app.url_map.iter_rules():
        if not rule.rule.startswith("/api") or rule.rule in DOC_ROUTES:
            continue
        path = re.sub(r"<(?:\w+:)?(\w+)>", r"{\1}", rule.rule)
        found |= {(path, m.lower()) for m in rule.methods - {"HEAD", "OPTIONS"}}
    return found


def test_the_spec_is_valid_openapi():
    validate(spec())


def test_every_route_is_documented_and_nothing_extra(app):
    documented = {(p, m) for p, methods in spec()["paths"].items() for m in methods}
    routes = _app_routes(app)
    assert routes - documented == set(), "add these to app/api_docs.py"
    assert documented - routes == set(), "these are documented but do not exist"


def test_docs_api_md_is_up_to_date():
    path = os.path.join(os.path.dirname(__file__), "..", "..", "docs", "API.md")
    with open(path, encoding="utf-8") as f:
        assert f.read() == markdown(), "run: flask --app run api-docs"


def test_swagger_page_and_spec_are_served(client):
    page = client.get("/api/docs")
    assert page.status_code == 200 and b"swagger-ui-bundle.js" in page.data
    assert client.get("/api/docs/files/swagger-ui-bundle.js").status_code == 200
    data = client.get("/api/openapi.json").get_json()
    assert data["info"]["title"] == "Anime World Shop API"
    assert data["servers"][0]["url"] == "http://localhost/"
