#!/usr/bin/env node

export async function main(): Promise<void> {
  const args = process.argv.slice(2);
  
  if (args.length === 0) {
    console.error("Usage: md2html <input.md> [--output <file>] [--theme <theme>]");
    process.exit(1);
  }
  
  console.log("Input file:", args[0]);
}

main().catch((error: Error) => {
  console.error("Error:", error.message);
  process.exit(1);
});
