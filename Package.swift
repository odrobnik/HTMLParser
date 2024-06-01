// swift-tools-version: 5.10

import PackageDescription

let package = Package(
	name: "HTMLParser",
	products: [
		.library(
			name: "HTMLParser",
			targets: ["HTMLParser"]),
	],
	targets: [
		.target(
			name: "HTMLParser",
			dependencies: ["CHTMLParser"]),
		.target(
			name: "CHTMLParser",
			path: "Sources/CHTMLParser",
			publicHeadersPath: "include"
		),
		.testTarget(
			name: "HTMLParserTests",
			dependencies: ["HTMLParser"]),
	]
)
