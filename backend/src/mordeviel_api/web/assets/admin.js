// Credentials stay in memory; no localStorage, cookie or URL tokens.
let adminToken=null, verification=null, editing=null, adminCards=[];
const adminStatus=(text,error=false)=>setMessage(text,error,'#admin-status');
function logout(){adminToken=null;verification=null;editing=null;adminCards=[];$('#admin-cards').replaceChildren();$('#admin-dashboard').hidden=true;$('#admin-login').hidden=false;$('#login-form').hidden=false;$('#verify-form').hidden=true;$('#password').value='';$('#verify-code').value='';$('#card-form').reset();$('#download-form').reset();$('#download-status').textContent='';adminStatus('Session fermée.');}
async function loadAdmin(){
  await loadCollectionAdmin();
  const mail=await api('/community/admin/mail-schedule',undefined,adminToken,'GET');
  fillMail(mail);
  const data=await api('/community/admin/site/cards',undefined,adminToken,'GET');adminCards=data.cards;
  const download=await api('/community/admin/site/download',undefined,adminToken,'GET');
  $('#download-url').value=download.download_url;$('#download-version').value=download.download_version;$('#download-enabled').checked=download.download_enabled;
  $('#admin-login').hidden=true;$('#admin-dashboard').hidden=false;
  const list=$('#admin-cards');list.replaceChildren();
  for(const card of adminCards){const row=document.createElement('article');row.className='admin-entry';
    if(card.published){const img=document.createElement('img');img.src=card.image_url;img.alt=card.title;row.append(img);}
    const details=document.createElement('div');const h=document.createElement('h3');h.textContent=card.title;const p=document.createElement('p');p.textContent=card.edition+' · '+(card.published?'Publiée':'Masquée');
    const edit=document.createElement('button');edit.type='button';edit.className='text-button';edit.textContent='Modifier';edit.addEventListener('click',()=>editCard(card));
    const remove=document.createElement('button');remove.type='button';remove.className='text-button';remove.textContent='Supprimer';remove.addEventListener('click',()=>{if(confirm('Supprimer cette carte de la vitrine ?'))busy($('#card-form'),async()=>{await api('/community/admin/site/cards/'+card.id,undefined,adminToken,'DELETE');if(editing===card.id)resetEditor();await loadAdmin();adminStatus('Carte retirée de la vitrine.');},'#admin-status');});
    details.append(h,p,edit,remove);row.append(details);list.append(row);
  }
}
function fillMail(mail){
  $('#mail-enabled').checked=mail.enabled;$('#mail-days').value=mail.interval_days;
  $('#mail-subject').value=mail.subject;$('#mail-phrases').value=mail.phrases.join('\n');
  $('#mail-next').textContent=(mail.enabled?'Prochain envoi : '+new Date(mail.next_due*1000).toLocaleString('fr-FR'):'Envois suspendus')+' · Envoyés : '+(mail.deliveries.sent||0)+' · Échecs : '+(mail.deliveries.failed||0)+' · En attente : '+(mail.deliveries.pending||0);
}
$('#mail-form').addEventListener('submit',event=>{event.preventDefault();busy(event.target,async()=>{
  const mail=await api('/community/admin/mail-schedule',{enabled:$('#mail-enabled').checked,interval_days:Number($('#mail-days').value),subject:$('#mail-subject').value.trim(),phrases:$('#mail-phrases').value.split('\n').map(p=>p.trim()).filter(Boolean)},adminToken,'PUT');fillMail(mail);setMessage('Planning enregistré.',false,'#mail-status');
},'#mail-status');});
$('#login-form').addEventListener('submit',event=>{event.preventDefault();busy(event.target,async()=>{
  const data=await api('/community/login',{nickname:$('#nickname').value.trim(),password:$('#password').value});$('#password').value='';
  if(data.user.role!=='admin')throw Error('Cet espace est réservé aux administrateurs.');
  adminToken=data.token;
  if(data.verification_required){verification=data.challenge_id;$('#login-form').hidden=true;$('#verify-form').hidden=false;adminStatus('Un code a été envoyé à ton adresse email.');$('#verify-code').focus();return;}
  try{await loadAdmin();adminStatus('Connexion administrateur réussie.');}catch(e){logout();throw e;}
},'#admin-status');});
$('#verify-form').addEventListener('submit',event=>{event.preventDefault();busy(event.target,async()=>{await api('/community/email/verify',{challenge_id:verification,code:$('#verify-code').value.trim()},adminToken);$('#verify-code').value='';await loadAdmin();adminStatus('Adresse vérifiée.');},'#admin-status');});
function resetEditor(){editing=null;$('#card-form').reset();$('#editor-title').textContent='Ajouter une carte';}
function editCard(card){editing=card.id;$('#title').value=card.title;$('#role').value=card.role_name;$('#edition').value=card.edition;$('#description').value=card.description;$('#position').value=card.position;$('#published').checked=card.published;$('#image').value='';$('#editor-title').textContent='Modifier la carte';$('#card-form').scrollIntoView({behavior:'smooth',block:'start'});$('#title').focus();}
$('#new-card').addEventListener('click',resetEditor);
$('#logout').addEventListener('click',async()=>{const token=adminToken;logout();try{await api('/community/logout',{},token);}catch{}});
$('#card-form').addEventListener('submit',event=>{event.preventDefault();busy(event.target,async()=>{
  const body={title:$('#title').value.trim(),role_name:$('#role').value.trim(),edition:$('#edition').value,description:$('#description').value.trim(),position:Number($('#position').value),published:$('#published').checked};
  const file=$('#image').files[0];if(!editing&&!file)throw Error('Choisis une image pour cette nouvelle carte.');
  if(file){if(file.size>4*1024*1024)throw Error('Image trop lourde : 4 Mo maximum.');body.image_base64=await new Promise((resolve,reject)=>{const reader=new FileReader();reader.onload=()=>resolve(reader.result.split(',')[1]);reader.onerror=()=>reject(Error('Lecture de l’image impossible.'));reader.readAsDataURL(file);});}
  await api('/community/admin/site/cards'+(editing?'/'+editing:''),body,adminToken,editing?'PUT':'POST');resetEditor();await loadAdmin();adminStatus('Carte enregistrée. La vitrine est à jour.');
},'#admin-status');});
window.addEventListener('pagehide',()=>{adminToken=null;});

$('#download-form').addEventListener('submit',event=>{
  event.preventDefault();busy(event.target,async()=>{
    const data=await api('/community/admin/site/download',{
      download_url:$('#download-url').value.trim(),
      download_version:$('#download-version').value.trim(),
      download_enabled:$('#download-enabled').checked
    },adminToken,'PUT');
    setMessage(data.download_enabled ? 'Lien publié : les boutons de la vitrine ouvrent ce téléchargement.' : 'Lien enregistré. Les boutons de téléchargement sont désactivés.',false,'#download-status');
  },'#download-status');
});

// Account collections: price null means no claim, independent of temporary free access.
let collectionAdmin = null;
const selection = id => [...$(id).selectedOptions].map(o=>o.value);
function collectionOptions(select, products, selected=[]){
  select.replaceChildren();
  for(const p of products){const option=document.createElement('option');option.value=p.id;option.textContent=p.title+' · '+p.theme+' · '+p.kind;option.selected=selected.includes(p.id);select.append(option);}
}
function fillCollectionProduct(){
  const p=collectionAdmin.products.find(p=>p.id===$('#collection-product').value);if(!p)return;
  $('#collection-price').value=p.price_minor??'';$('#collection-currency').value=p.currency;
  $('#collection-visible').checked=!!p.visible;$('#collection-shop').checked=!!p.shop;$('#collection-collector').checked=!!p.collector;
  collectionOptions($('#collection-bonus'),collectionAdmin.products.filter(v=>v.id!==p.id&&v.theme!=='classic'),p.bonus);
}
async function loadCollectionAdmin(){
  const old=$('#collection-product').value;
  collectionAdmin=await api('/community/admin/collection',undefined,adminToken,'GET');
  $('#collection-days').value=collectionAdmin.free_days_configured;
  $('#collection-duration').textContent='Disponible gratuitement jusqu’au '+collectionAdmin.free_until+' · '+collectionAdmin.free_days_remaining+' jours restants (UTC).';
  $('#collection-restrictions').textContent=collectionAdmin.free_access?'Activer les restrictions — test':'Rétablir l’accès gratuit';
  $('#collection-restrictions').setAttribute('aria-pressed',String(!collectionAdmin.free_access));
  const products=collectionAdmin.products.filter(p=>p.theme!=='classic');
  collectionOptions($('#collection-product'),products);if(products.some(p=>p.id===old))$('#collection-product').value=old;
  fillCollectionProduct();
  $('#collection-day').value=collectionAdmin.day;
  collectionOptions($('#collection-daily'),products.filter(p=>p.visible&&p.collector),collectionAdmin.daily_ids);
  $('#collection-start').value=collectionAdmin.day;$('#collection-end').value=collectionAdmin.day;
  collectionOptions($('#collection-trial-products'),products);
  const list=$('#collection-trials');list.replaceChildren();
  for(const t of collectionAdmin.trials){const row=document.createElement('p');row.textContent=t.title+' · '+t.starts+' → '+t.ends+' · '+(t.products.length?t.products.length+' produits':'Tous les produits');const remove=document.createElement('button');remove.type='button';remove.className='text-button';remove.textContent='Supprimer cet essai';remove.addEventListener('click',()=>busy(row,async()=>{await api('/community/admin/collection/trials/'+t.id,undefined,adminToken,'DELETE');await loadCollectionAdmin();},'#collection-status'));row.append(remove);list.append(row);}
}
$('#collection-product').addEventListener('change',fillCollectionProduct);
$('#collection-duration-form').addEventListener('submit',event=>{event.preventDefault();busy(event.target,async()=>{await api('/community/admin/collection/settings',{free_access:collectionAdmin.free_access,free_days:Number($('#collection-days').value)},adminToken,'PUT');await loadCollectionAdmin();setMessage('Durée gratuite enregistrée.',false,'#collection-status');},'#collection-status');});
$('#collection-restrictions').addEventListener('click',event=>busy(event.target,async()=>{
  await api('/community/admin/collection/settings',{free_access:!collectionAdmin.free_access},adminToken,'PUT');await loadCollectionAdmin();setMessage(collectionAdmin.free_access?'Accès gratuit rétabli.':'Restrictions de test actives. Actualise la collection dans l’application pour voir les verrous animés.',false,'#collection-status');
},'#collection-status'));
$('#collection-product-form').addEventListener('submit',event=>{event.preventDefault();busy(event.target,async()=>{
  const raw=$('#collection-price').value;
  await api('/community/admin/collection/products/'+$('#collection-product').value,{price_minor:raw===''?null:Number(raw),currency:$('#collection-currency').value,visible:$('#collection-visible').checked,shop:$('#collection-shop').checked,collector:$('#collection-collector').checked,bonus:selection('#collection-bonus')},adminToken,'PUT');await loadCollectionAdmin();setMessage('Produit et bonus enregistrés.',false,'#collection-status');
},'#collection-status');});
$('#collection-daily-form').addEventListener('submit',event=>{event.preventDefault();busy(event.target,async()=>{
  await api('/community/admin/collection/daily',{day:$('#collection-day').value,products:selection('#collection-daily')},adminToken,'PUT');await loadCollectionAdmin();setMessage('Offres du Collectionneur enregistrées.',false,'#collection-status');
},'#collection-status');});
$('#collection-trial-form').addEventListener('submit',event=>{event.preventDefault();busy(event.target,async()=>{
  await api('/community/admin/collection/trials',{title:$('#collection-trial-title').value.trim(),starts:$('#collection-start').value,ends:$('#collection-end').value,products:selection('#collection-trial-products'),enabled:true},adminToken,'POST');await loadCollectionAdmin();setMessage('Essai programmé.',false,'#collection-status');
},'#collection-status');});
