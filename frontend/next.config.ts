import path from "path";
import { fileURLToPath } from "url";
import type { NextConfig } from "next";

const __dirname = path.dirname(fileURLToPath(import.meta.url));

const nextConfig: NextConfig = {
  basePath: "/dashboard",
  assetPrefix: "/dashboard/",
  output: "export",
  trailingSlash: true,
  outputFileTracingRoot: path.join(__dirname),
  images: {
    unoptimized: true,
  },
};

export default nextConfig;
