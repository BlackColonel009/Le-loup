// Shared publication and email endpoints with the native application.
// Only draft text is persisted; credentials remain in memory in admin.js.
let announcementEditing = null, announcementDraftLoaded = false;
let announcementWorking = false;
const announcementMessage = (text, error=false) => setMessage(text, error, '#announcement-status');
const draftPrefix = () => 'mordeviel.announcement.' + adminUserId + '.';
const draftKey = () => draftPrefix() + (announcementEditing ?? 'new');
function saveAnnouncementDraft() {
  if (!adminUserId || announcementWorking) return;
  try {
    if (!$('#announcement-title').value && !$('#announcement-body').value) {
      localStorage.removeItem(draftKey());
      return;
    }
    localStorage.setItem(draftKey(), JSON.stringify({
      id: announcementEditing, title: $('#announcement-title').value,
      body: $('#announcement-body').value,
    }));
    localStorage.setItem(draftPrefix() + 'last', String(announcementEditing ?? 'new'));
    $('#announcement-draft-status').textContent = 'Brouillon enregistré dans ce navigateur, sans publication.';
  } catch (_) {
    $('#announcement-draft-status').textContent = 'Stockage local indisponible : gardez cette page ouverte pour conserver le texte.';
  }
}
function openAnnouncementEditor(item=null) {
  announcementEditing = item?.id ?? null;
  let draft;
  try { draft = JSON.parse(localStorage.getItem(draftKey()) || 'null'); } catch (_) {}
  $('#announcement-title').value = draft?.title ?? item?.title ?? '';
  $('#announcement-body').value = draft?.body ?? item?.body ?? '';
  $('#announcement-editor-title').textContent = item ? 'Modifier une annonce publiée' : 'Nouvelle annonce';
  $('#announcement-form button[type=submit]').textContent = item ? 'Enregistrer sur le site et dans le jeu' : 'Publier sur le site et dans le jeu';
  $('#announcement-draft-status').textContent = draft ? 'Brouillon restauré. Aucun changement publié.' : 'Les brouillons restent dans ce navigateur, sans être publiés.';
}
async function announcementAction(work) {
  if (announcementWorking || !adminToken) return;
  announcementWorking = true;
  const buttons = [...$('#announcements-admin').querySelectorAll('button,input,textarea')];
  buttons.forEach(b => b.disabled = true);
  try { await work(); }
  catch (error) { announcementMessage(error.message || 'Connexion indisponible. Votre brouillon est conservé.', true); }
  finally { announcementWorking = false; buttons.forEach(b => b.disabled = false); }
}
async function loadAnnouncementsAdmin() {
  const data = await api('/community/info', undefined, adminToken, 'GET');
  const items = data.announcements || [];
  if (!announcementDraftLoaded) {
    announcementDraftLoaded = true;
    let last;
    try { last = localStorage.getItem(draftPrefix() + 'last'); } catch (_) {}
    openAnnouncementEditor(items.find(item => String(item.id) === last) || null);
  }
  const list = $('#admin-announcements'); list.replaceChildren();
  if (!items.length) { const p=document.createElement('p'); p.textContent='Aucune annonce publiée.'; list.append(p); }
  for (const item of items) {
    const article=document.createElement('article'); article.className='admin-entry announcement-admin-entry';
    const content=document.createElement('div');
    const title=document.createElement('h3'); title.textContent=item.title;
    const text=document.createElement('p'); text.className='announcement-admin-body'; text.textContent=item.body;
    const date=document.createElement('p'); date.textContent='Publiée le '+new Date(item.published*1000).toLocaleString('fr-FR');
    const edit=document.createElement('button'); edit.type='button'; edit.className='text-button'; edit.textContent='Modifier';
    edit.onclick=()=>{if(announcementWorking)return;saveAnnouncementDraft();openAnnouncementEditor(item);$('#announcement-title').focus();};
    const email=document.createElement('button'); email.type='button'; email.className='text-button'; email.textContent='Envoyer / suivre les emails';
    email.onclick=()=>announcementAction(async()=>{
      const state=await api('/community/admin/content/'+item.id+'/email',undefined,adminToken,'GET');
      const d=state.deliveries;
      if (!confirm('Annonce publiée : « '+item.title+' »\nEnvoyés : '+(d.sent||0)+' · En attente : '+(d.pending||0)+' · Échecs : '+(d.failed||0)+' · Annulés : '+(d.cancelled||0)+'\n\nEnvoyer cette version aux comptes vérifiés et abonnés ? Le thème des rappels sera utilisé. Aucun doublon ni nouvelle tentative automatique des échecs.')) return;
      const result=await api('/community/admin/content/'+item.id+'/email',{},adminToken,'POST');
      announcementMessage(result.already_queued ? 'Cette version est déjà programmée : aucun nouvel envoi créé.' : result.queued+' email(s) mis en attente. La publication reste visible sur le site et dans le jeu.');
    });
    const hide=document.createElement('button'); hide.type='button'; hide.className='text-button'; hide.textContent='Masquer du site et du jeu';
    hide.onclick=()=>announcementAction(async()=>{
      if(!confirm('Masquer « '+item.title+' » sur le site et dans le jeu ? Les emails déjà envoyés ne peuvent pas être rappelés.'))return;
      await api('/community/admin/content/'+item.id,undefined,adminToken,'DELETE');
      if(announcementEditing===item.id)openAnnouncementEditor();
      await loadAnnouncementsAdmin(); announcementMessage('Annonce masquée sur le site et dans le jeu.');
    });
    content.append(title,date,text,edit,email,hide);article.append(content);list.append(article);
  }
}
$('#announcement-form').addEventListener('submit',event=>{
  event.preventDefault();saveAnnouncementDraft();
  announcementAction(async()=>{
    const title=$('#announcement-title').value.trim(),body=$('#announcement-body').value.trim();
    if(!title||!body)throw Error('Titre et texte requis.');
    const oldKey=draftKey(),id=announcementEditing;
    await api('/community/admin/content'+(id===null?'':'/'+id),{kind:'announcement',title,body},adminToken,id===null?'POST':'PUT');
    // Reset only after confirmed publication; email remains a separate action.
    try { localStorage.removeItem(oldKey); localStorage.removeItem(draftPrefix()+'last'); } catch (_) {}
    openAnnouncementEditor();
    announcementMessage('Annonce publiée sur le site et dans le jeu. Utilisez « Envoyer / suivre les emails » pour sa diffusion par mail.');
    try { await loadAnnouncementsAdmin(); }
    catch (_) { announcementMessage('Annonce enregistrée. Impossible d’actualiser la liste : utilisez Actualiser les annonces.',true); }
  });
});
for(const id of ['#announcement-title','#announcement-body'])$(id).addEventListener('input',saveAnnouncementDraft);
$('#announcement-new').onclick=()=>{saveAnnouncementDraft();openAnnouncementEditor();$('#announcement-title').focus();};
$('#announcement-discard').onclick=()=>{
  if(!confirm('Effacer ce brouillon ? Une annonce déjà publiée restera inchangée.'))return;
  try{localStorage.removeItem(draftKey());localStorage.removeItem(draftPrefix()+'last');}catch(_){}
  announcementEditing=null;$('#announcement-form').reset();openAnnouncementEditor();
};
$('#announcement-refresh').onclick=()=>announcementAction(loadAnnouncementsAdmin);
$('#logout').addEventListener('click',()=>{
  announcementDraftLoaded=false;announcementEditing=null;adminUserId=null;
  $('#announcement-form').reset();$('#admin-announcements').replaceChildren();
  announcementMessage('');$('#announcement-draft-status').textContent='Les brouillons restent dans ce navigateur, sans être publiés.';
});
