import { file } from "bun";

// Helper to ensure directory exists
async function ensureDir(path: string) {
  const dirs = path.split("/");
  let currentPath = "";
  
  for (const dir of dirs) {
    currentPath += dir + "/";
    try {
      await Bun.write(currentPath, "");
    } catch (e) {
      // Directory likely exists, continue
    }
  }
}

async function main() {
  // Read the XML file
  const xmlContent = await file("_docs/landmark2o1.xml").text();
  
  // Simple regex-based extraction (could be more robust with proper XML parsing)
  const fileMatches = xmlContent.matchAll(/<file path="([^"]+)"[^>]*>[\s\S]*?<content>\s*===\s*([\s\S]*?)\s*===\s*<\/content>/g);

  for (const match of fileMatches) {
    const [_, filePath, content] = match;
    
    // Ensure the directory structure exists
    const dirPath = filePath.split("/").slice(0, -1).join("/");
    await ensureDir(dirPath);
    
    // Write the file
    try {
      await Bun.write(filePath, content);
      console.log(`✓ Created ${filePath}`);
    } catch (err) {
      console.error(`✗ Failed to create ${filePath}:`, err);
    }
  }
}

// Run the script
main().catch(console.error); 