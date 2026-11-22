package com.brianward.quartzsitecampfire

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import java.io.File
import java.net.HttpURLConnection
import java.net.URL

// One ad, as the site sends it.
data class Listing(val id: String, val title: String, val price: String, val cat: String, val area: String, val text: String, val photos: List<String>, val sold: Boolean, val ts: Long)

data class AlertPost(val id: String, val text: String, val link: String, val ts: Long)

data class GuideCard(val title: String, val text: String, val map: String)
data class GuideList(val id: String, val section: String, val label: String, val cards: List<GuideCard>)
data class Show(val name: String, val whenText: String, val place: String, val confirmed: Boolean, val details: String)
data class Pin(val name: String, val lat: Double, val lon: Double, val kind: String, val text: String)
data class Guide(val lists: List<GuideList>, val shows: List<Show>, val pins: List<Pin>)

// Everything the app asks the website for.
object Site {
    const val BASE = "https://qcampfire.com"

    val cats = listOf("rv" to "RV parts and solar", "camp" to "Camping gear", "rocks" to "Rocks and gems", "wheels" to "Vehicles and off-road",
        "tools" to "Tools", "home" to "Household", "free" to "Free", "wanted" to "Wanted", "services" to "Services")

    fun catName(id: String): String = cats.firstOrNull { it.first == id }?.second ?: "Other"
    fun photo(id: String): String = "$BASE/_blob/$id"
    fun link(id: String): String = "$BASE/l/$id"

    fun ago(ts: Long): String {
        val minutes = ((System.currentTimeMillis() - ts) / 60000).coerceAtLeast(0)
        return when {
            minutes < 1 -> "just now"
            minutes < 60 -> "$minutes min ago"
            minutes < 1440 -> "${minutes / 60} hr ago"
            else -> "${minutes / 1440} days ago"
        }
    }

    private suspend fun get(path: String): String = withContext(Dispatchers.IO) {
        val con = URL(BASE + path).openConnection() as HttpURLConnection
        con.connectTimeout = 15000
        con.readTimeout = 20000
        try {
            if (con.responseCode >= 400) throw Exception("The site answered " + con.responseCode)
            con.inputStream.bufferedReader().use { it.readText() }
        } finally {
            con.disconnect()
        }
    }

    private fun strings(a: JSONArray?): List<String> {
        val out = ArrayList<String>()
        if (a != null) for (i in 0 until a.length()) out.add(a.optString(i))
        return out
    }

    suspend fun listings(): List<Listing> {
        val rows = JSONArray(get("/api/docs/listings"))
        val out = ArrayList<Listing>()
        for (i in 0 until rows.length()) {
            val row = rows.getJSONObject(i)
            val d = row.optJSONObject("data") ?: continue
            val title = d.optString("title")
            if (title.isEmpty()) continue
            out.add(Listing(row.optString("id"), title, d.optString("price"), d.optString("cat"), d.optString("area"), d.optString("text"),
                strings(d.optJSONArray("photos")), d.optBoolean("sold"), d.optLong("ts")))
        }
        return out.sortedByDescending { it.ts }
    }

    // Weather alerts and local news.
    suspend fun alerts(): List<AlertPost> {
        val rows = JSONArray(get("/api/docs/posts"))
        val out = ArrayList<AlertPost>()
        for (i in 0 until rows.length()) {
            val row = rows.getJSONObject(i)
            val d = row.optJSONObject("data") ?: continue
            if (d.optString("board") != "alerts" || d.optString("parent").isNotEmpty()) continue
            val text = d.optString("text")
            if (text.isEmpty()) continue
            out.add(AlertPost(row.optString("id"), text, d.optString("url"), d.optLong("ts")))
        }
        return out.sortedByDescending { it.ts }
    }

    private fun parseGuide(json: String): Guide {
        val o = JSONObject(json)
        val lists = ArrayList<GuideList>()
        val la = o.optJSONArray("lists") ?: JSONArray()
        for (i in 0 until la.length()) {
            val l = la.getJSONObject(i)
            val cards = ArrayList<GuideCard>()
            val ca = l.optJSONArray("cards") ?: JSONArray()
            for (j in 0 until ca.length()) {
                val c = ca.getJSONObject(j)
                cards.add(GuideCard(c.optString("title"), c.optString("text"), c.optString("map")))
            }
            lists.add(GuideList(l.optString("id"), l.optString("section"), l.optString("label"), cards))
        }
        val shows = ArrayList<Show>()
        val sa = o.optJSONArray("shows") ?: JSONArray()
        for (i in 0 until sa.length()) {
            val s = sa.getJSONObject(i)
            shows.add(Show(s.optString("n"), s.optString("w"), s.optString("p"), s.optString("s") == "ok", s.optString("d")))
        }
        val pins = ArrayList<Pin>()
        val pa = o.optJSONArray("pins") ?: JSONArray()
        for (i in 0 until pa.length()) {
            val p = pa.getJSONObject(i)
            pins.add(Pin(p.optString("name"), p.optDouble("lat"), p.optDouble("lon"), p.optString("kind"), p.optString("text")))
        }
        return Guide(lists, shows, pins)
    }

    // The guide that is on the phone already: the last one downloaded, or the copy that ships inside the app.
    suspend fun savedGuide(context: Context): Guide? = withContext(Dispatchers.IO) {
        val cache = File(context.cacheDir, "guide.json")
        try {
            if (cache.exists()) return@withContext parseGuide(cache.readText())
        } catch (e: Exception) { }
        try {
            parseGuide(context.assets.open("guide.json").bufferedReader().use { it.readText() })
        } catch (e: Exception) { null }
    }

    // The newest guide from the site, kept on the phone for next time.
    suspend fun freshGuide(context: Context): Guide {
        val json = get("/api/guide")
        val guide = parseGuide(json)
        withContext(Dispatchers.IO) { File(context.cacheDir, "guide.json").writeText(json) }
        return guide
    }
}
