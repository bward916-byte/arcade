# Campfire area data: Lake Havasu

Data for adding Lake Havasu City as an area in the one Campfire iPhone app (area picker). Not an app and not built by any workflow.

- `havasu/area.json`: the per-area settings the Quartzsite app hard-codes today (name, map centre, theme, ad areas, the free-versus-paid comparison, guide sections).
- `havasu/guide.json`: the guide in the app's own format (lists, areas, shows, pins). Decodes with the app's GuideData.
- `havasu/guide-full.json`: the same data with source notes and "unverified" flags.
- `havasu/swift-changes.patch`: the edits that turned a copy of `apps/campfire-ios` into a Havasu-only app. That copy compiled on the GitHub Mac (run 46119734855) and was then dropped in favour of the area picker. Use it as a list of every place Quartzsite is baked in.
- `havasu/web-preview.html`: the preview site (Guide, For Sale, Shows, Alerts, Map) to port to the Havasu website.
- `havasu/art-1024.png`: header art for the area (lake, bridge, balloon).

Gathered November 27, 2026 from official pages, business listings, forums and Facebook groups. Nothing has been confirmed by phone or on the ground.

Still missing for Havasu: a website and its address, a land-boundary file, coordinates for the service listings.
