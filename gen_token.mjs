import { generateJwt } from "@coinbase/cdp-sdk/auth";

const apiKeyId = process.env.CDP_API_KEY_ID;
const apiKeySecret = process.env.CDP_API_KEY_SECRET;

if (!apiKeyId || !apiKeySecret) {
  throw new Error("CDP_API_KEY_ID and CDP_API_KEY_SECRET must be set");
}

const token = await generateJwt({
  apiKeyId,
  apiKeySecret,
  requestMethod: "POST",
  requestHost: "api.cdp.coinbase.com",
  requestPath: "/platform/v2/evm/faucet",
});

console.log(token);