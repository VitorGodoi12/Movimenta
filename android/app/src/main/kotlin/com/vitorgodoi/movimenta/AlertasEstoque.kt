package com.vitorgodoi.movimenta

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.os.Build
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import org.json.JSONArray

internal object AlertasEstoque {
    private const val CANAL = "estoque_sonoro"
    private const val ID = 120
    private const val ACAO = "com.vitorgodoi.movimenta.VERIFICAR_ESTOQUE"
    private fun prefs(context: Context) =
        context.getSharedPreferences("alertas_estoque", Context.MODE_PRIVATE)

    private fun gerente(context: Context) = requireNotNull(context.getSystemService(NotificationManager::class.java))

    fun criarCanal(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val canal = NotificationChannel(CANAL, "Estoque e validade", NotificationManager.IMPORTANCE_HIGH)
            canal.description = "Produtos vencidos, próximos da validade ou abaixo do mínimo"
            canal.setSound(
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION),
                AudioAttributes.Builder().setUsage(AudioAttributes.USAGE_NOTIFICATION).build()
            )
            gerente(context).createNotificationChannel(canal)
        }
    }

    fun permitido(context: Context): Boolean {
        val manager = gerente(context)
        return manager.areNotificationsEnabled() &&
            (Build.VERSION.SDK_INT < Build.VERSION_CODES.O ||
                manager.getNotificationChannel(CANAL)?.importance != NotificationManager.IMPORTANCE_NONE)
    }

    fun sincronizar(context: Context, baixo: Int, datas: List<String>, dias: Int) {
        prefs(context).edit().putInt("baixo", baixo)
            .putString("datas", JSONArray(datas).toString()).putInt("dias", dias).apply()
        verificar(context)
        agendar(context)
    }

    fun agendar(context: Context) {
        val alarme = requireNotNull(context.getSystemService(AlarmManager::class.java))
        val evento = PendingIntent.getBroadcast(
            context, 0, Intent(context, AlertaEstoqueReceiver::class.java).setAction(ACAO),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        if (!permitido(context)) {
            alarme.cancel(evento)
            return
        }
        val proximo = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 9)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (timeInMillis <= System.currentTimeMillis()) add(Calendar.DAY_OF_YEAR, 1)
        }
        alarme.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, proximo.timeInMillis, evento)
    }

    fun verificar(context: Context) {
        criarCanal(context)
        if (!permitido(context)) return
        val dados = prefs(context)
        val formato = SimpleDateFormat("yyyy-MM-dd", Locale.ROOT)
        val hoje = formato.format(Calendar.getInstance().time)
        val limite = Calendar.getInstance().apply { add(Calendar.DAY_OF_YEAR, dados.getInt("dias", 7)) }
        val fim = formato.format(limite.time)
        val datas = JSONArray(dados.getString("datas", "[]") ?: "[]")
        var vencidos = 0
        val proximasDatas = sortedSetOf<String>()
        for (i in 0 until datas.length()) {
            val data = datas.getString(i)
            if (data < hoje) vencidos++ else if (data <= fim) proximasDatas.add(data)
        }
        val baixo = dados.getInt("baixo", 0)
        if (baixo + vencidos == 0 && proximasDatas.isEmpty()) {
            gerente(context).cancel(ID)
            return
        }
        val texto = listOfNotNull(
            "$baixo com estoque baixo ou zerado".takeIf { baixo > 0 },
            "$vencidos lote(s) com validade vencida".takeIf { vencidos > 0 },
            proximasDatas.takeIf { it.isNotEmpty() }?.joinToString(
                prefix = "Validades próximas: ",
                limit = 5,
                truncated = "…"
            ) { data -> data.split('-').asReversed().joinToString("/") }
        ).joinToString(" · ")
        val tocouHoje = dados.getString("ultimoDia", null) == hoje
        val mesmasDatas = dados.getString("ultimasDatas", null) == proximasDatas.joinToString()
        val notificacaoAtiva = gerente(context).activeNotifications.any { it.id == ID }
        if (tocouHoje && mesmasDatas && !notificacaoAtiva) return
        if (publicar(context, ID, "Seu estoque precisa de atenção", texto, tocouHoje && mesmasDatas)) {
            dados.edit().putString("ultimoDia", hoje).putString("ultimasDatas", proximasDatas.joinToString()).apply()
        }
    }

    fun testar(context: Context): Boolean {
        criarCanal(context)
        return publicar(context, ID + 1, "Notificação de teste do Stokio",
            "Os alertas do estoque estão ativos neste aparelho.", false)
    }

    @Suppress("DEPRECATION")
    private fun publicar(context: Context, id: Int, titulo: String, texto: String, silenciosa: Boolean): Boolean {
        if (!permitido(context)) return false
        val abrir = PendingIntent.getActivity(context, 0,
            Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O)
            Notification.Builder(context, CANAL)
        else Notification.Builder(context).setPriority(Notification.PRIORITY_HIGH)
            .setDefaults(if (silenciosa) 0 else Notification.DEFAULT_SOUND)
        try {
            gerente(context).notify(id, builder.setSmallIcon(R.drawable.ic_stokio_notificacao)
                .setContentTitle(titulo).setContentText(texto)
                .setStyle(Notification.BigTextStyle().bigText(texto))
                .setVisibility(Notification.VISIBILITY_PRIVATE)
                .setContentIntent(abrir).setAutoCancel(true).setOnlyAlertOnce(silenciosa).build())
            return true
        } catch (_: SecurityException) {
            return false
        }
    }
}

class AlertaEstoqueReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        AlertasEstoque.verificar(context)
        AlertasEstoque.agendar(context)
    }
}
