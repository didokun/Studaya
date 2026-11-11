#!/usr/bin/env python3
"""Build native lproj resources from public UI strings. No student data is used.
One-time machine-translation bootstrap; caches every completed locale for review.
Run --extract after xcodebuild SWIFT_EMIT_LOC_STRINGS=YES, then --translate.
Native-language editorial review is recommended before publishing.
"""
import argparse,concurrent.futures,json,pathlib,re,time,urllib.parse,urllib.request
ROOT=pathlib.Path(__file__).resolve().parent.parent
DATA=ROOT/'Localization'
LANGS=['en','fr','es','pt-BR','de','it','nl','pl','ru','uk','tr','ar','hi','zh-Hans','ja','ko']
GOOGLE={'pt-BR':'pt','zh-Hans':'zh-CN'}
FMT=re.compile(r'(?<!%)%(?!%)(?:\d+\$)?[-+0 #]*\d*(?:\.\d+)?(?:ll|l|h|hh)?[@diufeg]')
EN_OVERRIDES={
'Accueil':'Home','Planning':'Planner','Matières':'Subjects','Progrès':'Progress','Réglages':'Settings','Cours':'Lecture','TD':'Tutorial','Contrôle':'Test','Présentation':'Presentation','Examen':'Exam','Examen final':'Final exam','Rendu':'Assignment','Révision':'Study','Rappel':'Reminder','Semestre':'Semester',
'Lycée':'High school','BTS / BUT':'Vocational / technical degree','Licence':"Bachelor’s degree",'Master':"Master’s degree",'Doctorat':'Doctorate','Autre':'Other','Par semestre':'By semester','Par matière':'By subject','En fin de matière':'At the end of each subject','Apprentissage':'Learning','Entraînement':'Practice','Rappel actif':'Active recall','Rappel espacé':'Spaced review','Préparation':'Preparation','Focus libre':'Free focus',
'Commencer':'Start','Continuer':'Continue','Continuer gratuitement':'Continue for free','Plus tard':'Not now','Terminé':'Done','Terminée':'Completed','Fermer':'Close','Retour':'Back','Enregistrer':'Save','Annuler':'Cancel','Supprimer':'Delete','Reprendre':'Resume','Mettre en pause':'Pause','Réinitialiser':'Reset','Toute la matière':'Entire subject','Code (facultatif)':'Code (optional)','Code utilisé : ':'Code used: ',' · initiales automatiques si vide':' · initials are used automatically when empty','Nom de la matière':'Subject name','Nom du cours ou TD':'Lecture or tutorial name','Cours ou TD lié':'Linked lecture or tutorial',
'Prénom (facultatif)':'First name (optional)','Prénom':'First name','Formation':'Study program','Niveau d’études':'Education level','Ton année commence ici.':'Your year starts here.','Ton planning':'Your planner','Tes matières':'Your subjects','Mes matières':'My subjects','Créer mon Parcours de révision':'Create my study plan','Parcours de révision':'Study plan','Créer mon planning':'Create my schedule','Ton parcours est prêt':'Your study plan is ready','Ton planning est prêt !':'Your schedule is ready!',
'TON CAMPUS':'YOUR CAMPUS','TON PARCOURS':'YOUR STUDY PLAN','TON TEMPO':'YOUR PACE','TON ÉLAN DU JOUR':'TODAY’S MOMENTUM','DANS TA BULLE':'IN THE ZONE','RESPIRE UN INSTANT':'TAKE A BREATHER','CHAQUE EFFORT COMPTE':'EVERY EFFORT COUNTS','On prépare\nla suite ?':'Ready for\nwhat’s next?','Tes objectifs,\nun pas à la fois.':'Your goals,\none step at a time.','Une chose à la fois.':'One thing at a time.','Un moment Focus':'Time to focus','Tu l’as bien mérité.':'You’ve earned this.','Ton temps, ton attention':'Your time, your attention','Recharge tes batteries':'Recharge your batteries','Date à préciser':'Date not set','Date d’examen à préciser':'Exam date not set','Sans date':'No date','à préciser':'not set',
'%lld séances terminées sur %lld':'%1$lld of %2$lld sessions completed','%lld %% du travail suivi · ajoute tes cours et TD pour affiner ce suivi':'%1$lld%% of tracked work · add lectures and tutorials for a clearer picture','%lld sur 6':'%1$lld of 6','%lld séance(s) à faire':'%1$lld session(s) to do','%lld min restantes aujourd’hui':'%1$lld min remaining today','Prévisualisation · %lld sélectionné(s)':'Preview · %1$lld selected','%lld élément(s) sélectionné(s) · dates facultatives':'%1$lld selected · dates are optional',
'Contrôle · ':'Test · ','Présentation · ':'Presentation · ','Examen · ':'Exam · ','Examen final · ':'Final exam · ','Rappel · ':'Reminder · ','Rappel espacé · ':'Spaced review · ','Rappel ':'Reminder ','Échéance · ':'Deadline · ','Progression · ':'Progress · ','Ta réponse · ':'Your answer · ',
'Bilan Focus':'Focus summary','Rythme de révision':'Study routine','Bilan du soir':'Evening check-in','Planning du matin':'Morning planner','À l’heure des séances':'At session start time','Séance enregistrée':'Session saved','Valider mon profil':'Save my profile','Valider le bilan':'Save summary','Synchroniser avec Calendrier Apple':'Sync with Apple Calendar','Calendrier Apple':'Apple Calendar','Ajouter une matière':'Add a subject','Ajouter un cours ou un TD':'Add a lecture or tutorial','Ajouter au parcours':'Add to study plan','Ajouter à la matière':'Add to subject','Importer une photo':'Import a photo','Prendre une photo':'Take a photo','Galerie':'Photo library','Calendrier':'Calendar','Semaine':'Week','Jour':'Day','Mois suivant':'Next month','Mois précédent':'Previous month','Précédente':'Previous','Suivante':'Next',
'Dim':'Sun','Lun':'Mon','Mar':'Tue','Mer':'Wed','Jeu':'Thu','Ven':'Fri','Sam':'Sat','Dimanche':'Sunday','Lundi':'Monday','Mardi':'Tuesday','Mercredi':'Wednesday','Jeudi':'Thursday','Vendredi':'Friday','Samedi':'Saturday',
'Des présentations à préparer ? Ajoute leur titre et leur date limite, ou continue si tu n’en as pas.':'Any presentations to prepare? Choose a lecture or tutorial and an optional deadline, or continue if you have none.',
'Retrouve tes séances dans Planner et ton suivi dans Révision.':'Find your sessions in Planner and track your work in Subjects.'}
EXTRA=['Cours','TD','Contrôle','Présentation','Examen','Examen final','Rendu','Révision','Rappel','Semestre','Lycée','BTS / BUT','Licence','Master','Doctorat','Autre','Par semestre','Par matière','En fin de matière','Apprentissage','Entraînement','Rappel actif','Rappel espacé','Préparation','Révision de cours','à préciser','Niveau','Établissement',
'NSCameraUsageDescription','NSCalendarsFullAccessUsageDescription']
PURPOSE={'NSCameraUsageDescription':'Studaya utilise l’appareil photo pour lire le planning que tu souhaites importer dans une matière.','NSCalendarsFullAccessUsageDescription':'Studaya crée un calendrier dédié pour tes révisions et échéances. L’accès complet permet de retrouver, mettre à jour et supprimer uniquement les événements exportés par Studaya.'}

def extract():
 base=pathlib.Path('/tmp/studaya-build/Build/Intermediates.noindex/Studaya.build/Debug-iphonesimulator')
 keys=set();widget=set()
 for target in ['Studaya','StudayaFocusWidget']:
  for path in (base/(target+'.build')/'Objects-normal'/'arm64').glob('*.stringsdata'):
   data=json.loads(path.read_text())
   for item in data.get('tables',{}).get('Localizable',[]):
    key=item['key'];keys.add(key)
    if target=='StudayaFocusWidget':widget.add(key)
 keys.discard('analyse numer');keys.update(EXTRA);keys.update(EN_OVERRIDES)
 templates=json.loads((DATA/'notification-templates.json').read_text()) if (DATA/'notification-templates.json').exists() else {}
 keys.update(templates)
 # Existing English StoreKit keys already have reviewed French values.
 french={}
 existing=ROOT/'Studaya/fr.lproj/Localizable.strings'
 if existing.exists():
  for match in re.finditer(r'("(?:\\.|[^"\\])*")\s*=\s*("(?:\\.|[^"\\])*")\s*;',existing.read_text()):
   french[json.loads(match[1])]=json.loads(match[2])
 source={key:PURPOSE.get(key,french.get(key,key)) for key in sorted(keys)}
 source['Des présentations à préparer ? Ajoute leur titre et leur date limite, ou continue si tu n’en as pas.']='Des présentations à préparer ? Choisis un cours ou TD et une date facultative, ou continue si tu n’en as pas.'
 DATA.mkdir(exist_ok=True)
 previous=json.loads((DATA/'source.json').read_text()) if (DATA/'source.json').exists() else {}
 (DATA/'source.json').write_text(json.dumps({'strings':source,'widgetKeys':sorted(widget),'englishKeys':previous.get('englishKeys',[k for k,v in source.items() if k!=v and k not in PURPOSE])},ensure_ascii=False,indent=2)+'\n')
 print('EXTRACTED',len(source),'keys',flush=True)

def protect(text):
 formats=[]
 def replace(m):
  spec=m.group();index=len(formats)+1
  formats.append(spec if re.match(r'^%\d+\$',spec) else '%'+str(index)+'$'+spec[1:])
  return 'ZXQARG%06dZXQ'%(index-1)
 protected=FMT.sub(replace,text.replace('%%','ZXQPERCENTZXQ'))
 return protected,formats

def restore(text,formats):
 for i,spec in enumerate(formats):
  token=re.compile(r'ZXQ\s*ARG\s*0*'+str(i)+r'\s*ZXQ',re.I)
  if len(token.findall(text))!=1:raise ValueError('Lost placeholder '+str(i))
  text=token.sub(lambda _:spec,text)
 text=text.replace('ZXQPERCENTZXQ','%%')
 if 'ZXQARG' in text:raise ValueError('Unexpected placeholder')
 return text

def request(text,target,source):
 query=urllib.parse.urlencode({'client':'gtx','sl':source,'tl':GOOGLE.get(target,target),'dt':'t','q':text})
 request=urllib.request.Request('https://translate.googleapis.com/translate_a/single?'+query,headers={'User-Agent':'Mozilla/5.0'})
 last=None
 for attempt in range(4):
  try:
   with urllib.request.urlopen(request,timeout=45) as response:data=json.load(response)
   return ''.join(segment[0] for segment in data[0] if segment[0])
  except Exception as error:
   last=error;time.sleep([3,8,20,30][attempt])
 raise last

def translate_locale(locale,source,overrides=None):
 path=DATA/(locale+'.json');values=json.loads(path.read_text()) if path.exists() else {}
 if overrides:values.update(overrides)
 pending=[k for k in source if k not in values]
 # Preserve diagnostic codes, numeric-only formats and brand names.
 for key in list(pending):
  if not re.search(r'[^\W\d_]\w{1,}',FMT.sub('',source[key]),re.UNICODE) or source[key] in ['Studaya','Studaya Premium','Focus','Premium','AI','S1','S2']:
   values[key]=source[key];pending.remove(key)
 batches=[];current=[];size=0
 for key in pending:
  cost=len(source[key])+32
  if current and size+cost>1800:batches.append(current);current=[];size=0
  current.append(key);size+=cost
 if current:batches.append(current)
 for n,batch in enumerate(batches):
  formats={};parts=[]
  for i,key in enumerate(batch):
   text,formats[i]=protect(source[key]);parts.append('ZXQ%06dZXQ\n%s'%(i,text))
  translated=request('\n'.join(parts),locale,'fr' if locale=='en' else 'en')
  markers=list(re.finditer(r'ZXQ\s*(\d{6})\s*ZXQ',translated,re.I))
  output={}
  for i,m in enumerate(markers):output[int(m[1])]=translated[m.end():markers[i+1].start() if i+1<len(markers) else len(translated)].strip()
  for i,key in enumerate(batch):
   try:
    text=restore(output[i],formats[i])
    if not text and source[key].strip():raise ValueError('Empty translation')
   except (KeyError,ValueError):
    protected,fmt=protect(source[key]);text=restore(request(protected,locale,'fr' if locale=='en' else 'en'),fmt)
   # Preserve deliberate padding around concatenated fragments.
   if source[key].startswith(' ') and not text.startswith(' '):text=' '+text
   if source[key].endswith(' ') and not text.endswith(' '):text+=' '
   if source[key].startswith('\n') and not text.startswith('\n'):text='\n'+text
   values[key]=text
  path.write_text(json.dumps(values,ensure_ascii=False,indent=2)+'\n')
  print(locale,n+1,'/',len(batches),flush=True);time.sleep(.6)
 return values

def strings_file(path,values):
 path.parent.mkdir(parents=True,exist_ok=True)
 path.write_text('// Generated from Localization/*.json; see scripts/localize-resources.py.\n'+''.join(json.dumps(k,ensure_ascii=False)+' = '+json.dumps(v,ensure_ascii=False)+';\n' for k,v in sorted(values.items())))

def notification_templates(values):
 path=DATA/'notification-templates.json'
 if not path.exists():return
 for key,definition in json.loads(path.read_text()).items():
  if 'kind' in definition:values[key]=values[definition['kind']]+' · %1$@'
  elif 'literal' in definition:values[key]=definition['literal']
  else:values[key]='%1$@'+re.sub(r'%(?:1\$)?lld', '%2$lld',values[definition['fragment']])

def emit():
 data=json.loads((DATA/'source.json').read_text());source=data['strings']
 notification_templates(source)
 for locale in LANGS:
  values=source if locale=='fr' else json.loads((DATA/(locale+'.json')).read_text())
  editorial=DATA/'core-reviewed.json'
  if editorial.exists():values.update(json.loads(editorial.read_text()).get(locale,{}))
  notification_templates(values)
  missing=set(source)-set(values)
  if missing:raise ValueError(f'{locale}: {len(missing)} missing strings')
  for key,value in values.items():
   expected=FMT.findall(source[key]);actual=FMT.findall(value)
   if len(expected)!=len(actual):raise ValueError(f'{locale}: format mismatch: {key}')
  strings_file(ROOT/'Studaya'/(locale+'.lproj')/'Localizable.strings',{k:v for k,v in values.items() if k not in PURPOSE})
  strings_file(ROOT/'Studaya'/(locale+'.lproj')/'InfoPlist.strings',{k:values[k] for k in PURPOSE})
  strings_file(ROOT/'StudayaFocusWidget'/(locale+'.lproj')/'Localizable.strings',{k:values[k] for k in data['widgetKeys']})
 print('EMITTED',len(LANGS),'locales',len(source),'keys',flush=True)

if __name__=='__main__':
 parser=argparse.ArgumentParser();parser.add_argument('--extract',action='store_true');parser.add_argument('--translate',action='store_true');parser.add_argument('--emit',action='store_true');args=parser.parse_args()
 if args.extract:extract()
 if args.translate:
  data=json.loads((DATA/'source.json').read_text());source=data['strings']
  reviewed={k:v for k,v in EN_OVERRIDES.items() if k in source}
  # Keys originating in English have an English source key and a French source value.
  for key in data.get('englishKeys',[]):reviewed[key]=key
  english=translate_locale('en',source,reviewed)
  with concurrent.futures.ThreadPoolExecutor(max_workers=2) as pool:
   jobs=[pool.submit(translate_locale,locale,english) for locale in LANGS if locale not in ['en','fr']]
   for job in concurrent.futures.as_completed(jobs):job.result()
 if args.emit:emit()
