"""Email-safe table layout with inline styles and escaped content."""
from html import escape


def reminder_html(text, base, unsubscribe):
    body = escape(text).replace('\n', '<br>')
    site, optout = escape(base, quote=True), escape(unsubscribe, quote=True)
    return f'''<!doctype html>
<html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Le village vous attend</title></head>
<body style="margin:0;padding:0;background-color:#0b111a;color:#f2eadc;font-family:Arial,Helvetica,sans-serif;">
<div style="display:none;max-height:0;overflow:hidden;opacity:0;">Le conseil se rassemble… Retrouvez la communauté de Legende of Wolf.</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" bgcolor="#0b111a" style="background-color:#0b111a;"><tr><td align="center" style="padding:28px 12px;">
<table role="presentation" width="600" cellpadding="0" cellspacing="0" bgcolor="#152232" style="width:100%;max-width:600px;background-color:#152232;border:1px solid #b38b4d;border-radius:16px;overflow:hidden;">
<tr><td align="center" bgcolor="#101b29" style="padding:30px 24px 24px;border-bottom:1px solid #675336;background-color:#101b29;">
<img src="{site}/site-assets/logo.png" width="96" alt="Legende of Wolf" style="display:block;width:96px;height:auto;margin:0 auto 16px;border:0;">
<p style="margin:0 0 10px;color:#e4bd7a;font-size:12px;letter-spacing:3px;">LE CONSEIL DU VILLAGE</p>
<h1 style="margin:0;color:#fff3d9;font-family:Georgia,serif;font-size:30px;line-height:1.25;">Legende of Wolf</h1>
</td></tr>
<tr><td style="padding:32px 28px 16px;color:#f2eadc;font-size:16px;line-height:1.7;">
<p style="margin:0 0 20px;color:#d8e0e9;">Bonsoir, âme du village,</p>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" bgcolor="#1c2e40" style="background-color:#1c2e40;border-left:3px solid #d7ae6b;"><tr><td style="padding:20px;color:#fff3d9;font-family:Georgia,serif;font-size:21px;line-height:1.6;">{body}</td></tr></table>
<p style="margin:24px 0 0;color:#d8e0e9;">Retrouvez vos compagnons, partagez vos soupçons et préparez votre prochaine partie. Une nouvelle histoire vous attend.</p>
</td></tr>
<tr><td align="center" style="padding:16px 28px 32px;">
<table role="presentation" cellpadding="0" cellspacing="0"><tr><td bgcolor="#e0b978" style="background-color:#e0b978;border-radius:8px;"><a href="{site}" style="display:inline-block;padding:16px 26px;color:#101b29;font-weight:bold;font-size:16px;text-decoration:none;">Retrouver le village</a></td></tr></table>
<p style="margin:20px 0 0;color:#bac8d8;font-size:13px;line-height:1.6;">Gardez vos amis près de vous… et vos soupçons encore plus près.</p>
</td></tr>
<tr><td align="center" bgcolor="#101b29" style="padding:24px;border-top:1px solid #675336;background-color:#101b29;color:#bac8d8;font-size:12px;line-height:1.8;">
<p style="margin:0;color:#e4bd7a;font-size:15px;font-weight:bold;">Legende of Wolf · by Logan R.D</p>
<p style="margin:8px 0 14px;">Vous recevez ce rappel en tant que membre de la communauté.</p>
<a href="{optout}" style="color:#e4bd7a;text-decoration:underline;">Ne plus recevoir ces rappels</a>
<p style="margin:12px 0 0;">Votre compte restera actif après la désinscription.</p>
</td></tr></table>
<p style="margin:18px 0 0;color:#bac8d8;font-size:12px;"><a href="{site}/confidentialite" style="color:#bac8d8;">Confidentialité</a></p>
</td></tr></table></body></html>'''
