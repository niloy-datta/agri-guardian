"""Stateless packages must not break migration discovery."""

from types import ModuleType, SimpleNamespace
from unittest.mock import patch

import pytest

from app.core.model_discovery import import_models


@pytest.fixture(autouse=True)
def clean_tables():
    """These isolated import tests do not access a database."""


def _package():
    package = ModuleType("test_domains")
    package.__path__ = []
    return package


def test_only_existing_model_modules_are_imported():
    modules = [SimpleNamespace(name=name, ispkg=True) for name in ("identity", "email_auth")]
    modules.append(SimpleNamespace(name="helpers", ispkg=False))
    with (
        patch("app.core.model_discovery.pkgutil.iter_modules", return_value=modules),
        patch("app.core.model_discovery.importlib.util.find_spec", side_effect=[object(), None]),
        patch("app.core.model_discovery.importlib.import_module") as load,
    ):
        import_models(_package())
    load.assert_called_once_with("test_domains.identity.models")


def test_missing_dependency_inside_existing_models_is_not_hidden():
    with (
        patch("app.core.model_discovery.pkgutil.iter_modules", return_value=[SimpleNamespace(name="identity", ispkg=True)]),
        patch("app.core.model_discovery.importlib.util.find_spec", return_value=object()),
        patch("app.core.model_discovery.importlib.import_module", side_effect=ModuleNotFoundError("missing dependency")),
        pytest.raises(ModuleNotFoundError, match="missing dependency"),
    ):
        import_models(_package())
