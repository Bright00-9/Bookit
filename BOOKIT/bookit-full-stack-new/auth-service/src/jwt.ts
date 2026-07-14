import jwt, { SignOptions } from 'jsonwebtoken';
import { config } from './config';

export interface JwtPayload {
  sub: string; // user id
  email: string;
  role: string;
}

export function signToken(payload: JwtPayload): string {
  // jsonwebtoken's types are strict about the shape of `expiresIn` (it wants
  // a number of seconds, or a specific string-literal-like union, not a
  // general `string`). Since our value genuinely comes from an env var at
  // runtime, we assert the type here rather than losing the env var's
  // flexibility — this is a case where `strict` mode is right to flag it,
  // but the fix is a targeted assertion, not disabling the check globally.
  const options: SignOptions = { expiresIn: config.jwtExpiresIn as SignOptions['expiresIn'] };
  return jwt.sign(payload, config.jwtSecret, options);
}

export function verifyToken(token: string): JwtPayload {
  return jwt.verify(token, config.jwtSecret) as JwtPayload;
}
