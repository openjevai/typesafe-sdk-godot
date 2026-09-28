# OpenJEV support

This fork adds **optional** [OpenJEV](https://openjev.sh) support alongside the
existing TypeSafe integration. OpenJEV is a free community gateway to the same
Jev model built by [TypeSafe](https://typesafe.ai). TypeSafe remains the
default; anyone with a TypeSafe key sees zero behaviour change.

## What was added

- `addons/typesafe_sdk/core/constants.gd` — new constants: `OPENJEV_API_KEY_ENV`
  (`"OPENJEV_API_KEY"`), `JEV_PROVIDER_ENV` (`"JEV_PROVIDER"`),
  `OPENJEV_DEFAULT_BASE_URL` (`"https://api.openjev.sh"`),
  `OPENJEV_DEFAULT_MODEL` (`"openjev"`). All TypeSafe constants are unchanged.
- `addons/typesafe_sdk/core/config.gd` — `TypeSafeConfig.resolve()` now performs
  provider selection (additive, only affects env fallbacks and defaults) and
  stores the resolved provider on `config.provider`. New static helper
  `_select_provider()`. All explicit-arg behaviour is unchanged.
- `addons/typesafe_sdk/README.md` — OpenJEV note after the intro, env-var list
  updated. No TypeSafe text removed.
- `addons/typesafe_sdk/examples/example.gd` — comment describing the OpenJEV
  env option.

No TypeSafe endpoint, model, env var, default, or documentation was renamed,
removed, or re-defaulted.

## Provider selection rule

Implemented in `TypeSafeConfig._select_provider()`, evaluated when no explicit
`api_key` / `base_url` / `model` argument is supplied (explicit args always win):

1. `JEV_PROVIDER=openjev` env → **OpenJEV** (explicit choice wins).
2. Otherwise, if `TYPESAFE_API_KEY` is set → **TypeSafe** (unchanged default).
3. Otherwise, if only `OPENJEV_API_KEY` is set → **OpenJEV**.
4. Otherwise → **TypeSafe** defaults (unchanged).

When OpenJEV is selected, the defaults become base URL
`https://api.openjev.sh`, model `openjev`, and the key is read from
`OPENJEV_API_KEY`. `TYPESAFE_BASE_URL` / `TYPESAFE_DEFAULT_MODEL` still override
the base URL / model for either provider (they are generic overrides).

| | TypeSafe (default) | OpenJEV (optional) |
|---|---|---|
| Endpoint | `https://api.typesafe.ai/v1/systemone` | `https://api.openjev.sh/v1/systemone` |
| Model | `jev-latest` | `openjev` |
| Key env | `TYPESAFE_API_KEY` | `OPENJEV_API_KEY` |
| Overload | 529 | 503 (already covered by the 500–599 retry range) |

## How to configure

```bash
# TypeSafe (unchanged default)
export TYPESAFE_API_KEY="ts-..."

# OpenJEV (optional) — only when no TypeSafe key is set
export OPENJEV_API_KEY="oj-..."

# Or force OpenJEV even if a TypeSafe key is also present
export JEV_PROVIDER=openjev
export OPENJEV_API_KEY="oj-..."
```

Then use the SDK exactly as before — `TypeSafeClient.new()`,
`client.system_one(state, questions)`, etc. The resolved provider is available
on `client.config.provider` (`"typesafe"` or `"openjev"`).

## How it was verified

The repository's own code was never executed. Verification was a single live
`POST https://api.openjev.sh/v1/systemone` request (model `openjev`, state
`"ping"`, one `noul` question) with the OpenJEV API key, which returned HTTP 200
with a valid `answers` body. A final grep confirmed no hardcoded
`api.typesafe.ai` default was introduced or left where OpenJEV should be used.

## Upstream

Original project: https://github.com/IAmNo1Special/typesafe-sdk-godot by
@IAmNo1Special (MIT license, preserved).
