--!strict
-- Generate local LiveTransportConfig.lua using the relay setup; never commit credentials.
return table.freeze({Url="http://localhost:8765/exchange", Token="REPLACE_WITH_LOCALLY_GENERATED_TOKEN"})
