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
