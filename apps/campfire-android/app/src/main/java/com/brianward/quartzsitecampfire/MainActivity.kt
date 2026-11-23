package com.brianward.quartzsitecampfire

import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Info
import androidx.compose.material.icons.filled.Notifications
import androidx.compose.material.icons.filled.Place
import androidx.compose.material.icons.filled.ShoppingCart
import androidx.compose.material3.Button
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.FilterChip
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage

// The site's colors.
val Primary = Color(0xFF0A6F69)
val Accent = Color(0xFFC2431A)
val Page = Color(0xFFECE8E1)
val CardColor = Color(0xFFFEFCF7)

// Quartzsite Campfire for Android: ads, guide, shows, alerts and places, all read from the live site.
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            MaterialTheme(colorScheme = lightColorScheme(primary = Primary, secondary = Accent, background = Page, surface = CardColor)) {
                Root()
            }
        }
    }
}

fun openLink(context: Context, url: String) {
    try { context.startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(url))) } catch (e: Exception) { }
}

// The five tabs. The guide is loaded once here and shared by Guide, Shows and Places.
@Composable
fun Root() {
    val context = LocalContext.current
    var tab by rememberSaveable { mutableStateOf("sale") }
    var guide by remember { mutableStateOf<Guide?>(null) }
    LaunchedEffect(Unit) {
        guide = Site.savedGuide(context)
        try { guide = Site.freshGuide(context) } catch (e: Exception) { }
    }
    Scaffold(
        containerColor = Page,
        bottomBar = {
            NavigationBar(containerColor = CardColor) {
                NavigationBarItem(selected = tab == "sale", onClick = { tab = "sale" }, icon = { Icon(Icons.Filled.ShoppingCart, null) }, label = { Text("For Sale") })
                NavigationBarItem(selected = tab == "guide", onClick = { tab = "guide" }, icon = { Icon(Icons.Filled.Info, null) }, label = { Text("Guide") })
                NavigationBarItem(selected = tab == "shows", onClick = { tab = "shows" }, icon = { Icon(Icons.Filled.DateRange, null) }, label = { Text("Shows") })
                NavigationBarItem(selected = tab == "alerts", onClick = { tab = "alerts" }, icon = { Icon(Icons.Filled.Notifications, null) }, label = { Text("Alerts") })
                NavigationBarItem(selected = tab == "places", onClick = { tab = "places" }, icon = { Icon(Icons.Filled.Place, null) }, label = { Text("Places") })
            }
        }
    ) { pad ->
        Box(Modifier.padding(pad).fillMaxSize()) {
            when (tab) {
                "sale" -> ForSaleScreen()
                "guide" -> GuideScreen(guide)
                "shows" -> ShowsScreen(guide)
                "alerts" -> AlertsScreen()
                else -> PlacesScreen(guide)
            }
        }
    }
}

@Composable
fun Heading(text: String) {
    Text(text, style = MaterialTheme.typography.headlineSmall, fontWeight = FontWeight.Bold, modifier = Modifier.padding(16.dp, 16.dp, 16.dp, 8.dp))
}

@Composable
fun Note(text: String) {
    Text(text, color = Color.Gray, modifier = Modifier.padding(16.dp))
}

@Composable
fun Loading() {
    Box(Modifier.fillMaxWidth().padding(32.dp), contentAlignment = Alignment.Center) { CircularProgressIndicator() }
}

@Composable
fun Panel(onClick: (() -> Unit)? = null, content: @Composable () -> Unit) {
    val base = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 6.dp)
    Card(modifier = if (onClick != null) base.clickable { onClick() } else base, colors = CardDefaults.cardColors(containerColor = CardColor), shape = RoundedCornerShape(14.dp)) {
        Column(Modifier.padding(14.dp)) { content() }
    }
}

// ---------- For Sale ----------

@Composable
fun ForSaleScreen() {
    val context = LocalContext.current
    var ads by remember { mutableStateOf<List<Listing>?>(null) }
    var failed by remember { mutableStateOf(false) }
    var open by remember { mutableStateOf<Listing?>(null) }
    var cat by rememberSaveable { mutableStateOf("") }
    var find by rememberSaveable { mutableStateOf("") }
    LaunchedEffect(Unit) {
        try { ads = Site.listings() } catch (e: Exception) { failed = true }
    }
    val one = open
    if (one != null) {
        AdDetail(one) { open = null }
        return
    }
    LazyColumn(Modifier.fillMaxSize()) {
        item { Heading("For sale around Quartzsite") }
        item {
            Button(onClick = { openLink(context, Site.BASE + "/#sale") }, modifier = Modifier.padding(horizontal = 16.dp)) { Text("Post an ad") }
        }
        item {
            OutlinedTextField(value = find, onValueChange = { find = it }, label = { Text("Search ads") }, singleLine = true, modifier = Modifier.fillMaxWidth().padding(16.dp, 8.dp))
        }
        item {
            Row(Modifier.horizontalScroll(rememberScrollState()).padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                FilterChip(selected = cat == "", onClick = { cat = "" }, label = { Text("All") })
                for (c in Site.cats) FilterChip(selected = cat == c.first, onClick = { cat = c.first }, label = { Text(c.second) })
            }
        }
        val all = ads
        if (all == null) {
            item { if (failed) Note("Ads need a signal to load. Open this tab again to retry.") else Loading() }
        } else {
            val q = find.trim().lowercase()
            val shown = all.filter { (cat == "" || it.cat == cat) && (q.isEmpty() || (it.title + " " + it.text).lowercase().contains(q)) }
            if (shown.isEmpty()) item { Note("No ads here yet.") }
            items(shown, key = { it.id }) { ad ->
                Panel(onClick = { open = ad }) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        if (ad.photos.isNotEmpty()) {
                            AsyncImage(model = Site.photo(ad.photos[0]), contentDescription = null, contentScale = ContentScale.Crop,
                                modifier = Modifier.size(72.dp).clip(RoundedCornerShape(10.dp)).background(Page))
                            Spacer(Modifier.width(12.dp))
                        }
                        Column(Modifier.weight(1f)) {
                            Text(ad.title, fontWeight = FontWeight.SemiBold, maxLines = 2, overflow = TextOverflow.Ellipsis)
                            Text(if (ad.sold) "Sold" else ad.price, color = if (ad.sold) Color.Gray else Accent, fontWeight = FontWeight.Bold)
                            Text(Site.catName(ad.cat) + " · " + Site.ago(ad.ts), color = Color.Gray, style = MaterialTheme.typography.bodySmall)
                        }
                    }
                }
            }
        }
        item { Spacer(Modifier.height(16.dp)) }
    }
}

@Composable
fun AdDetail(ad: Listing, back: () -> Unit) {
    val context = LocalContext.current
    LazyColumn(Modifier.fillMaxSize()) {
        item { TextButton(onClick = back, modifier = Modifier.padding(8.dp)) { Text("‹ Back to ads") } }
        items(ad.photos) { p ->
            AsyncImage(model = Site.photo(p), contentDescription = "Photo of " + ad.title, contentScale = ContentScale.FillWidth,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 6.dp).clip(RoundedCornerShape(14.dp)))
        }
        item {
            Panel {
                Text(ad.title, style = MaterialTheme.typography.titleLarge, fontWeight = FontWeight.Bold)
                Text(if (ad.sold) "Sold" else ad.price, color = Accent, fontWeight = FontWeight.Bold)
                Text(Site.catName(ad.cat) + " · " + Site.ago(ad.ts), color = Color.Gray, style = MaterialTheme.typography.bodySmall)
                Spacer(Modifier.height(8.dp))
                Text(ad.text)
                Spacer(Modifier.height(12.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button(onClick = { openLink(context, Site.link(ad.id)) }) { Text("Message seller") }
                    OutlinedButton(onClick = {
                        val send = Intent(Intent.ACTION_SEND).setType("text/plain").putExtra(Intent.EXTRA_TEXT, Site.link(ad.id))
                        context.startActivity(Intent.createChooser(send, "Share this ad"))
                    }) { Text("Share") }
                }
            }
        }
    }
}

// ---------- Guide ----------

private val sections = listOf("start" to "Start here", "camping" to "Camping", "wash" to "Washes", "services" to "Services", "rocks" to "Rockhounding",
    "mines" to "Gold and ghost camps", "trips" to "Trips and trails", "nature" to "Plants and animals", "town" to "Town")

@Composable
fun GuideScreen(guide: Guide?) {
    val context = LocalContext.current
    var section by rememberSaveable { mutableStateOf("start") }
    var find by rememberSaveable { mutableStateOf("") }
    var openCard by rememberSaveable { mutableStateOf("") }
    LazyColumn(Modifier.fillMaxSize()) {
        item { Heading("Quartzsite Guide") }
        item {
            OutlinedTextField(value = find, onValueChange = { find = it }, label = { Text("Search the guide") }, singleLine = true, modifier = Modifier.fillMaxWidth().padding(16.dp, 0.dp, 16.dp, 8.dp))
        }
        item {
            Row(Modifier.horizontalScroll(rememberScrollState()).padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                for (s in sections) FilterChip(selected = section == s.first && find.isBlank(), onClick = { section = s.first; find = "" }, label = { Text(s.second) })
            }
        }
        if (guide == null) {
            item { Loading() }
        } else {
            val q = find.trim().lowercase()
            for (list in guide.lists) {
                val cards = if (q.isEmpty()) (if (list.section == section) list.cards else emptyList()) else list.cards.filter { (it.title + " " + it.text).lowercase().contains(q) }
                if (cards.isEmpty()) continue
                item { Text(list.label, color = Color.Gray, fontWeight = FontWeight.SemiBold, modifier = Modifier.padding(16.dp, 14.dp, 16.dp, 2.dp)) }
                items(cards) { card ->
                    val key = list.id + "|" + card.title
                    Panel(onClick = { openCard = if (openCard == key) "" else key }) {
                        Text(card.title, fontWeight = FontWeight.SemiBold)
                        if (openCard == key) {
                            Spacer(Modifier.height(6.dp))
                            Text(card.text)
                            if (card.map.isNotEmpty()) TextButton(onClick = { openLink(context, card.map) }) { Text("Open in Google Maps") }
                        }
                    }
                }
            }
        }
        item { Spacer(Modifier.height(16.dp)) }
    }
}

// ---------- Shows ----------

@Composable
fun ShowsScreen(guide: Guide?) {
    LazyColumn(Modifier.fillMaxSize()) {
        item { Heading("Shows and events") }
        if (guide == null) item { Loading() }
        else items(guide.shows) { s ->
            Panel {
                Text(s.name, fontWeight = FontWeight.SemiBold)
                Text(s.whenText, color = Accent, fontWeight = FontWeight.Bold)
                Text(s.place, color = Color.Gray, style = MaterialTheme.typography.bodySmall)
                Text(if (s.confirmed) "Dates confirmed" else "Check dates before you go", color = if (s.confirmed) Primary else Color.Gray, style = MaterialTheme.typography.bodySmall)
                if (s.details.isNotEmpty()) { Spacer(Modifier.height(6.dp)); Text(s.details) }
            }
        }
        item { Spacer(Modifier.height(16.dp)) }
    }
}

// ---------- Alerts ----------

@Composable
fun AlertsScreen() {
    val context = LocalContext.current
    var posts by remember { mutableStateOf<List<AlertPost>?>(null) }
    var failed by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        try { posts = Site.alerts() } catch (e: Exception) { failed = true }
    }
    LazyColumn(Modifier.fillMaxSize()) {
        item { Heading("Alerts and conditions") }
        val all = posts
        if (all == null) item { if (failed) Note("Alerts need a signal to load.") else Loading() }
        else {
            if (all.isEmpty()) item { Note("Nothing posted right now.") }
            items(all, key = { it.id }) { p ->
                Panel {
                    Text(p.text)
                    Text(Site.ago(p.ts), color = Color.Gray, style = MaterialTheme.typography.bodySmall)
                    if (p.link.startsWith("http")) TextButton(onClick = { openLink(context, p.link) }) { Text("Read more") }
                }
            }
        }
        item { Spacer(Modifier.height(16.dp)) }
    }
}

// ---------- Places ----------

private val groups = listOf("" to "All", "camp" to "Camping", "svc" to "Services", "food" to "Food", "med" to "Medical", "see" to "Sights and trips")

private fun groupOf(kind: String): String = if (kind == "ltva" || kind == "free") "camp" else kind

// A list of every mapped place. Directions opens the phone's own maps app.
@Composable
fun PlacesScreen(guide: Guide?) {
    val context = LocalContext.current
    var show by rememberSaveable { mutableStateOf("") }
    LazyColumn(Modifier.fillMaxSize()) {
        item { Heading("Places") }
        item {
            Row(Modifier.horizontalScroll(rememberScrollState()).padding(horizontal = 16.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                for (g in groups) FilterChip(selected = show == g.first, onClick = { show = g.first }, label = { Text(g.second) })
            }
        }
        if (guide == null) item { Loading() }
        else items(guide.pins.filter { show == "" || groupOf(it.kind) == show }.sortedBy { it.name }) { pin ->
            Panel {
                Text(pin.name, fontWeight = FontWeight.SemiBold)
                if (pin.text.isNotEmpty()) Text(pin.text, maxLines = 3, overflow = TextOverflow.Ellipsis, style = MaterialTheme.typography.bodySmall)
                TextButton(onClick = { openLink(context, "geo:0,0?q=" + pin.lat + "," + pin.lon + "(" + Uri.encode(pin.name) + ")") }) { Text("Directions") }
            }
        }
        item { Spacer(Modifier.height(16.dp)) }
    }
}
