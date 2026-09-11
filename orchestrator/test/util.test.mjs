import { test } from "node:test";
import assert from "node:assert/strict";
import { slugify, truncate } from "../util.mjs";

test("truncate returns empty string for falsy inputs", () => {
  assert.equal(truncate("", 10), "");
  assert.equal(truncate(undefined, 10), "");
  assert.equal(truncate(null, 10), "");
  assert.equal(truncate(0, 10), "");
});

test("truncate returns text unchanged when shorter than max", () => {
  assert.equal(truncate("abc", 10), "abc");
});

test("truncate returns text unchanged at the boundary (length === max)", () => {
  assert.equal(truncate("abcde", 5), "abcde");
});

test("truncate appends exact suffix when text is longer than max", () => {
  assert.equal(truncate("abcdef", 5), "abcde\n... [truncated 1 chars]");
});

test("truncate with max === 0 on non-empty text returns empty prefix plus suffix", () => {
  assert.equal(truncate("abc", 0), "\n... [truncated 3 chars]");
});

test("truncate slices multi-line text byte-for-byte with no newline handling", () => {
  assert.equal(truncate("ab\ncd\nef", 5), "ab\ncd\n... [truncated 3 chars]");
});

test("slugify lowercases and hyphenates spaces", () => {
  assert.equal(slugify("Hello World"), "hello-world");
});

test("slugify collapses punctuation runs and trims edge dashes", () => {
  assert.equal(slugify("  ---Hello,   World!!! ---  "), "hello-world");
});

test("slugify preserves digits", () => {
  assert.equal(slugify("TASK-001 Fix Bug"), "task-001-fix-bug");
});

test("slugify is idempotent for already-slug input", () => {
  assert.equal(slugify("hello-world"), "hello-world");
});

test("slugify drops non-ASCII characters instead of transliterating", () => {
  assert.equal(slugify("café"), "caf");
  assert.equal(slugify("日本語"), "objective");
});

test("slugify falls back to 'objective' for empty, punctuation-only or max=0 inputs", () => {
  assert.equal(slugify(""), "objective");
  assert.equal(slugify("!!!"), "objective");
  assert.equal(slugify("---"), "objective");
  assert.equal(slugify("hello world", 0), "objective");
});

test("slugify default max is 40, explicit max is respected", () => {
  assert.equal(slugify("a".repeat(50)), "a".repeat(40));
  assert.equal(slugify("hello world", 5), "hello");
});

test("slugify truncates after edge-dash trim, so result can end with '-' (documents current behavior)", () => {
  const input = "a b c d e f g h i j k l m n o p q r s t u";
  const result = slugify(input);
  assert.equal(result.length, 40);
  assert.ok(result.endsWith("-"));
  assert.equal(result, "a-b-c-d-e-f-g-h-i-j-k-l-m-n-o-p-q-r-s-t-");
});

test("slugify throws TypeError on undefined/null input (documents current behavior, no falsy guard)", () => {
  assert.throws(() => slugify(undefined), TypeError);
  assert.throws(() => slugify(null), TypeError);
});
