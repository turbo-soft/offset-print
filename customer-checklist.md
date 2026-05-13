# Offset Print — šta nam treba za novi sajt

## Sadržaj

- Logo — najveća verzija koju imate (vektor SVG/AI/PDF ako postoji)
- Slike proizvoda — 3–6 po kategoriji (kartonska ambalaža, talasasta ambalaža, papirne etikete)
- Linkovi društvenih mreža (Facebook, Instagram, LinkedIn) ili „nemamo"
- Potvrditi telefon, adresu i radno vreme
- Pročitati tekstove na stranicama (O nama, Proizvodi, Politika privatnosti) i reći šta da promenim

## Pristup nalozima

- Domen `offsetprint.eu` — ko ga je registrovao i ko ima pristup
- AWS nalog — postoji ili ga pravimo zajedno (treba kartica, hosting je par evra mesečno)
- GitHub nalog — postoji ili ga pravimo zajedno

## Email — bitno

Da ne pukne `office@offsetprint.eu` kad prebacimo sajt, treba mi sa trenutnog hostinga:

- MX zapisi
- SPF (TXT zapis, počinje sa `v=spf1`)
- DKIM (TXT zapis, duži niz slova)
- DMARC (TXT zapis na `_dmarc.offsetprint.eu`)

Najlakše: screenshot cele DNS stranice kod registrara. Ako mejl ide preko Google Workspace, Microsoft 365 ili Wix-a, samo recite koje — imam gotove zapise.

