// Credentials stay in memory; no localStorage, cookie or URL tokens.
let adminToken=null, verification=null, editing=null, adminCards=[];
const adminStatus=(text,error=false)=>setMessage(text,error,'#admin-status');
function logout(){adminToken=null;verification=null;editing=null;adminCards=[];$('#admin-cards').replaceChildren();$('#admin-dashboard').hidden=true;$('#admin-login').hidden=false;$('#login-form').hidden=false;$('#verify-form').hidden=true;$('#password').value='';$('#verify-code').value='';$('#card-form').reset();$('#download-form').reset();$('#download-status').textContent='';adminStatus('Session fermée.');}
async function loadAdmin(){
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
