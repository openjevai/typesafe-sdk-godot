class_name TypeSafeConfig
extends RefCounted
## Client configuration. Mirrors Python client env handling + validation.
## Explicit args take precedence over env vars; empty/whitespace-only env
## values are ignored. An explicitly empty api_key does NOT fall back to env.

const DEFAULT_BASE_URL: String = "https://api.typesafe.ai"
const DEFAULT_MODEL: String = "jev-latest"
const DEFAULT_TIMEOUT: float = 10.0

const API_PATH_SYSTEM_ONE: String = "/v1/systemone"
const API_PATH_MODELS: String = "/v1/models"

# OpenJEV provider selection (additive — TypeSafe stays the default).
# 1. JEV_PROVIDER=openjev env -> OpenJEV (explicit choice wins).
# 2. Otherwise, if TYPESAFE_API_KEY is set -> TypeSafe (unchanged default).
# 3. Otherwise, if only OPENJEV_API_KEY is set -> OpenJEV.
# Explicit api_key / base_url / model args always override env-based defaults.
const PROVIDER_TYPESAFE: String = "typesafe"
const PROVIDER_OPENJEV: String = "openjev"

var api_key: String = ""
var base_url: String = DEFAULT_BASE_URL
var default_model: String = DEFAULT_MODEL
var timeout: float = DEFAULT_TIMEOUT
var default_headers: Dictionary = {}
var provider: String = PROVIDER_TYPESAFE

static func resolve(p_api_key: Variant = null, p_base_url: Variant = null, p_default_model: Variant = null, p_timeout: float = -1.0, p_default_headers: Dictionary = {}) -> TypeSafeConfig:
	var config = TypeSafeConfig.new()

	# Provider selection (only affects env fallbacks / defaults; explicit args
	# below always win). See the PROVIDER_* constants for the rule.
	var provider := _select_provider()
	config.provider = provider

	# API key: null/omitted -> env (provider-chosen key env); explicit "" -> error.
	var api_key := ""
	if p_api_key == null:
		var key_env := TypeSafeConstants.API_KEY_ENV
		if provider == PROVIDER_OPENJEV:
			key_env = TypeSafeConstants.OPENJEV_API_KEY_ENV
		api_key = _env_non_empty(key_env)
	else:
		api_key = str(p_api_key)

	api_key = api_key.strip_edges()
	if api_key == "":
		if p_api_key == null:
			TypeSafeLogger.error("No API key was provided. Pass api_key or set the TYPESAFE_API_KEY (or OPENJEV_API_KEY with JEV_PROVIDER=openjev) environment variable.")
		else:
			TypeSafeLogger.error("API key is empty. Provide a valid key (explicit empty keys do not fall back to the environment).")
	elif not _is_valid_api_key(api_key):
		TypeSafeLogger.error("API key must contain only printable ASCII characters without whitespace.")
	# Never log the key value itself.
	config.api_key = api_key

	# Base URL: explicit non-empty wins, else non-empty env, else provider default.
	var base_url := ""
	if p_base_url != null and str(p_base_url).strip_edges() != "":
		base_url = str(p_base_url).strip_edges()
	else:
		base_url = _env_non_empty(TypeSafeConstants.BASE_URL_ENV)
	if base_url.strip_edges() == "":
		base_url = TypeSafeConstants.OPENJEV_DEFAULT_BASE_URL if provider == PROVIDER_OPENJEV else TypeSafeConstants.DEFAULT_BASE_URL
	config.base_url = base_url.strip_edges().rstrip("/")

	# Model: null/"" -> env -> provider default.
	var model := ""
	if p_model_is_set(p_default_model):
		model = str(p_default_model).strip_edges()
	if model == "":
		model = _env_non_empty(TypeSafeConstants.DEFAULT_MODEL_ENV)
	if model == "":
		model = TypeSafeConstants.OPENJEV_DEFAULT_MODEL if provider == PROVIDER_OPENJEV else TypeSafeConstants.DEFAULT_MODEL
	config.default_model = model

	# Timeout: < 0 inherits default; must be positive finite.
	var timeout := p_timeout
	if timeout < 0.0:
		timeout = TypeSafeConstants.DEFAULT_TIMEOUT
	if timeout <= 0.0 or not is_finite(timeout):
		TypeSafeLogger.error("timeout must be a positive, finite number of seconds.")
		timeout = TypeSafeConstants.DEFAULT_TIMEOUT
	config.timeout = timeout

	config.default_headers = p_default_headers.duplicate() if typeof(p_default_headers) == TYPE_DICTIONARY else {}

	return config

static func p_model_is_set(p_value: Variant) -> bool:
	return p_value != null and str(p_value).strip_edges() != ""

static func _select_provider() -> String:
	# 1. Explicit JEV_PROVIDER env wins.
	var provider := _env_non_empty(TypeSafeConstants.JEV_PROVIDER_ENV)
	if provider != "":
		return provider.to_lower()
	# 2. TypeSafe key set -> TypeSafe (default unchanged).
	if _env_non_empty(TypeSafeConstants.API_KEY_ENV) != "":
		return PROVIDER_TYPESAFE
	# 3. Only OpenJEV key set -> OpenJEV.
	if _env_non_empty(TypeSafeConstants.OPENJEV_API_KEY_ENV) != "":
		return PROVIDER_OPENJEV
	# 4. Nothing set -> TypeSafe default.
	return PROVIDER_TYPESAFE

static func _env_non_empty(p_name: String) -> String:
	var v := OS.get_environment(p_name)
	if v.strip_edges() == "":
		return ""
	return v.strip_edges()

static func _is_valid_api_key(p_key: String) -> bool:
	# Reject empty, internal whitespace, control chars, non-ASCII.
	if p_key == "":
		return false
	for i in p_key.length():
		var o := int(p_key.unicode_at(i))
		if o <= 32 or o == 127 or o > 126:
			return false
		# unicode_at returns codepoint; non-ASCII (>126) rejected.
	return true

static func is_finite(p_val: float) -> bool:
	return not is_nan(p_val) and not is_inf(p_val)

static func is_nan(p_val: float) -> bool:
	return p_val != p_val

static func is_inf(p_val: float) -> bool:
	return p_val == INF or p_val == -INF

func system_one_url() -> String:
	return base_url + API_PATH_SYSTEM_ONE

func models_url() -> String:
	return base_url + API_PATH_MODELS