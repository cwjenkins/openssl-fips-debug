config_diagnostics = 1
openssl_conf = openssl_init

# Need to set the absolute path.
# https://github.com/openssl/openssl/issues/17704
.include ${HOME}/.local/${OPENSSL_TAG}-fips-debug/ssl/fipsmodule.cnf

[openssl_init]
providers = provider_sect
alg_section = algorithm_sect

[provider_sect]
fips = fips_sect
base = base_sect

[base_sect]
activate = 1

[algorithm_sect]
default_properties = fips=yes
