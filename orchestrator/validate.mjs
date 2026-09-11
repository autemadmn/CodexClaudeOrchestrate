/** Tiny JSON-Schema (subset) validator: type, enum, required, properties, additionalProperties, items, minItems, minimum, maximum, minLength, pattern. */
export function validate(schema, data, path = "$") {
  const errors = [];
  const t = schema.type;
  const typeOf = (v) => (v === null ? "null" : Array.isArray(v) ? "array" : typeof v);
  if (t) {
    const types = Array.isArray(t) ? t : [t];
    const actual = typeOf(data);
    const ok = types.some((x) => (x === "integer" ? Number.isInteger(data) : x === "number" ? typeof data === "number" : x === actual));
    if (!ok) {
      errors.push(`${path}: expected ${types.join("|")}, got ${actual}`);
      return errors;
    }
  }
  if (schema.enum && !schema.enum.includes(data)) errors.push(`${path}: value ${JSON.stringify(data)} not in enum [${schema.enum.join(", ")}]`);
  if (typeof data === "string") {
    if (schema.minLength != null && data.length < schema.minLength) errors.push(`${path}: shorter than ${schema.minLength}`);
    if (schema.pattern && !new RegExp(schema.pattern).test(data)) errors.push(`${path}: does not match ${schema.pattern}`);
  }
  if (typeof data === "number") {
    if (schema.minimum != null && data < schema.minimum) errors.push(`${path}: below minimum ${schema.minimum}`);
    if (schema.maximum != null && data > schema.maximum) errors.push(`${path}: above maximum ${schema.maximum}`);
  }
  if (Array.isArray(data)) {
    if (schema.minItems != null && data.length < schema.minItems) errors.push(`${path}: fewer than ${schema.minItems} items`);
    if (schema.items) data.forEach((item, i) => errors.push(...validate(schema.items, item, `${path}[${i}]`)));
  }
  if (data && typeof data === "object" && !Array.isArray(data)) {
    for (const key of schema.required || []) if (!(key in data)) errors.push(`${path}: missing required "${key}"`);
    const props = schema.properties || {};
    for (const [key, val] of Object.entries(data)) {
      if (props[key]) errors.push(...validate(props[key], val, `${path}.${key}`));
      else if (schema.additionalProperties === false) errors.push(`${path}: unexpected property "${key}"`);
    }
  }
  return errors;
}

export function assertValid(schema, data, label) {
  const errors = validate(schema, data);
  if (errors.length) throw new Error(`${label} failed schema validation:\n  - ${errors.slice(0, 15).join("\n  - ")}`);
  return data;
}
