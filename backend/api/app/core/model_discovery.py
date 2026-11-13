"""Load ORM models without requiring stateless modules to define tables."""

import importlib
import importlib.util
import pkgutil
from types import ModuleType


def import_models(package: ModuleType) -> None:
    for module in pkgutil.iter_modules(package.__path__):
        if not module.ispkg:
            continue
        name = f"{package.__name__}.{module.name}.models"
        if importlib.util.find_spec(name) is not None:
            # Do not catch import errors: a missing dependency inside an existing
            # model is a broken deployment and must fail migration startup.
            importlib.import_module(name)
