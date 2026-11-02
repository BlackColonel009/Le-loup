const $ = (s) => document.querySelector(s);
async function api(path, body, token, method = 'POST') {
  const response = await fetch(path, {method, headers: {'Content-Type':'application/json', ...(token ? {Authorization: 'Bearer ' + token} : {})}, ...(body === undefined ? {} : {body: JSON.stringify(body)}), signal: AbortSignal.timeout(15000)});
  const data = await response.json().catch(() => ({detail: response.status === 413 ? 'Image trop volumineuse pour le serveur. Réduisez-la puis réessayez.' : 'Le serveur est momentanément indisponible.'}));
  if (!response.ok) throw new Error(typeof data.detail === 'string' ? data.detail : 'Vérifiez les champs puis réessayez.');
  return data;
}
function setMessage(text, error = false, selector = '#form-status') {
  const target = $(selector); if (!target) return;
  target.textContent = text; target.className = error ? 'status-error' : 'status-success';
}
async function busy(form, work, selector) {
  const buttons = [...form.querySelectorAll('button')]; buttons.forEach(b => b.disabled = true);
  try { await work(); } catch(error) { setMessage(error.name === 'TimeoutError' ? 'Le serveur tarde à répondre. Réessayez.' : (error.message || 'Connexion impossible. Réessayez.'), true, selector); }
  finally {buttons.forEach(b => b.disabled = false);}
}
let challenge = null;
$('#delete-request')?.addEventListener('submit', event => {
  event.preventDefault(); busy(event.target, async () => {
    const data = await api('/community/account-deletion/request', {email: $('#email').value.trim()});
    challenge = data.challenge_id; setMessage(data.message); $('#delete-request').hidden = true; $('#delete-confirm').hidden = false; $('#code').focus();
  });
});
$('#delete-confirm')?.addEventListener('submit', event => {
  event.preventDefault(); if (!challenge || !$('#consent').checked) return;
  busy(event.target, async () => {
    const data = await api('/community/account-deletion/confirm', {challenge_id:challenge, code:$('#code').value.trim(), confirm:true});
    challenge=null; $('#delete-confirm').hidden=true; $('#code').value=''; setMessage(data.message);
  });
});
$('#restart')?.addEventListener('click', () => {challenge=null; $('#delete-request').hidden=false; $('#delete-confirm').hidden=true; $('#code').value=''; $('#consent').checked=false; setMessage(''); $('#email').focus();});
function applyDownload(data) {
  if (!data.download_url) return;
  let url; try { url=new URL(data.download_url); } catch { return; }
  if (url.protocol !== 'https:' || url.username || url.password) return;
  const mega=['mega.nz','mega.io','mega.co.nz'].includes(url.hostname);
  const label=mega ? 'Télécharger l’APK Android sur MEGA ↗' : 'Télécharger l’APK Android ↗';
  document.querySelectorAll('[data-download-link], [data-download-hero]').forEach(link=>{
    link.href=data.download_url; link.target='_blank'; link.rel='noopener noreferrer'; link.textContent=label;
  });
  document.querySelectorAll('[data-download-area]').forEach(area=>area.hidden=false);
  document.querySelectorAll('[data-download-unavailable]').forEach(area=>area.hidden=true);
  document.querySelectorAll('[data-download-info]').forEach(info=>info.textContent=(data.download_version ? 'Version '+data.download_version+' · ' : '')+'Le téléchargement s’ouvre sur un site externe. Installez l’APK Android une fois le fichier téléchargé.');
}
fetch('/site-config').then(r=>r.json()).then(data=>{ applyDownload(data); if (!data.support_email || !/^[^\s<>@]+@[^\s<>@]+\.[^\s<>@]+$/.test(data.support_email)) return; document.querySelectorAll('[data-support-contact]').forEach(target=>{target.textContent='Vous pouvez aussi nous écrire : '; const a=document.createElement('a');a.href='mailto:'+data.support_email;a.textContent=data.support_email;target.append(a);});}).catch(()=>{});
let gallery=[];
function renderGallery(edition='classic'){
  const container=$('#gallery-cards'); if (!container) return; container.replaceChildren();
  const cards=gallery.filter(c=>c.edition===edition);
  if (!cards.length){const p=document.createElement('p');p.textContent='Les visuels de cette édition seront présentés prochainement.';container.append(p);return;}
  for(const card of cards){const article=document.createElement('article');article.className='gallery-card';const img=document.createElement('img');img.src=card.image_url;img.alt='Carte '+card.title;img.loading='lazy';img.width=230;img.height=345;const h=document.createElement('h3');h.textContent=card.title;const p=document.createElement('p');p.textContent=card.description;const small=document.createElement('small');small.textContent=card.role_name;article.append(img,small,h,p);container.append(article);}
}
if($('#gallery-cards')) fetch('/gallery/cards').then(r=>{if(!r.ok)throw Error();return r.json();}).then(data=>{gallery=data.cards;renderGallery();}).catch(()=>{$('#gallery-cards').textContent='La galerie est momentanément indisponible. Réessayez plus tard.';});
document.querySelectorAll('[data-edition]').forEach(button=>button.addEventListener('click',()=>{document.querySelectorAll('[data-edition]').forEach(b=>b.setAttribute('aria-pressed',String(b===button)));renderGallery(button.dataset.edition);}));

// Same visible publications as the game. All announcement text stays plain text.
let announcements = [], announcementsLimit = 3, announcementsLoading = false;
function renderAnnouncements() {
  const list = $('#announcements-list'); if (!list) return;
  list.replaceChildren();
  if (!announcements.length) {
    const empty = document.createElement('p'); empty.textContent = 'Le conseil n’a pas encore publié d’annonce. Revenez bientôt !'; list.append(empty);
  }
  for (const item of announcements.slice(0, announcementsLimit)) {
    const article = document.createElement('article'); article.className = 'announcement-card'; article.id = 'annonce-' + Number(item.id);
    const date = new Date(Number(item.published) * 1000);
    if (Number.isFinite(date.getTime())) {
      const time = document.createElement('time'); time.dateTime = date.toISOString();
      time.textContent = 'Publié le ' + new Intl.DateTimeFormat('fr-FR', {day:'numeric',month:'long',year:'numeric'}).format(date); article.append(time);
    }
    const title = document.createElement('h3'); title.textContent = item.title;
    const body = item.body; const preview = document.createElement('p');
    preview.textContent = body.length > 280 ? body.slice(0,280) + '…' : body; article.append(title, preview);
    if (body.length > 280) {
      const details = document.createElement('details'); const summary = document.createElement('summary'); summary.textContent = 'Lire l’annonce complète';
      const full = document.createElement('p'); full.textContent = body; details.append(summary, full); article.append(details);
    }
    list.append(article);
  }
  $('#announcements-more').hidden = announcements.length <= announcementsLimit;
}
async function loadAnnouncements({quiet=false}={}) {
  const list = $('#announcements-list'); if (!list || announcementsLoading) return;
  announcementsLoading = true; list.setAttribute('aria-busy','true'); $('#announcements-refresh').disabled = true;
  try {
    const response = await fetch('/community/info', {cache:'no-store', signal:AbortSignal.timeout(15000)});
    if (!response.ok) throw Error('Announcements unavailable');
    const data = await response.json(); if (!Array.isArray(data.announcements)) throw Error('Invalid announcements');
    announcements = data.announcements.filter(item => item.kind === 'announcement' && typeof item.title === 'string' && typeof item.body === 'string')
      .sort((a,b) => Number(b.published)-Number(a.published) || Number(b.id)-Number(a.id));
    renderAnnouncements();
  } catch {
    if (!quiet || !list.querySelector('.announcement-card')) {
      list.replaceChildren(); const error = document.createElement('p'); error.textContent = 'Les annonces sont momentanément indisponibles. Utilisez « Actualiser les annonces » pour réessayer.'; list.append(error);
    }
  } finally {
    announcementsLoading = false; list.setAttribute('aria-busy','false'); $('#announcements-refresh').disabled = false;
  }
}
if ($('#announcements-list')) {
  loadAnnouncements();
  $('#announcements-refresh').addEventListener('click', () => loadAnnouncements());
  $('#announcements-more').addEventListener('click', () => {announcementsLimit += 3; renderAnnouncements();});
  setInterval(() => {if (!document.hidden) loadAnnouncements({quiet:true});}, 60000);
}
