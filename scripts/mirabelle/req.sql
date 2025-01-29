select rowid, code, creator, url, last_modified_datetime, product_name 
  from [all] where 

  /* search for these words */
  url REGEXP "caca|mi?erd|salop|conar|connar|couil|degueulas|encule|etron|excrement|pipi|puant|putrid|sex|urine|vagin|zizi|cock|disgusting|fuck|rotten|shit|stink|penis"

  /* but excluding these ones */
  and url NOT REGEXP "alheira-de-caca|chancaca|cacaks|caca(o|u)|cacah(u|o)|guasacaca|cacarena|cacarola|cacafe|decacake|magnetron|petron(a|e|i)|serrapetron|merda-d(e|i)-can|fiasconaro|couilles?-du-pape|merd(e|a)ka|somerdale|sommerdinkel|summerdown|pipi-de-marmotte|pipi-du-dragon|pipin-pear|pipinetto|pipin(\'|g)|pipian|pipino|pipirai|pipirm|pipistrelli|sexton|sexy-?pop|sussex|unisexe|wessex|figurine|maurine|pippurinen|saurine|seigneurine|signurine|tannourine|taurine|verdurine|yogurine|sauvagine|zizi-?coin-?coin|(/|-)zizin|ziziphus|-cock$|cock-flavour-soup|cockatoo|cockburn|cock-a-leekie|cock-n-bull|hitchcock|peacock|poppycock|spatchcock|cock-?brand|cock-mint|cockle|cockta|cocktel|lecock|fucking-delicious|muckefuck|grotten|karotten|rottenburger|sprotten|the-rotten-fruit-box|ashitaki|cashita|fishitos|hashita|no-bullshit|sarashita|shishito|shitake|shito|sushita|yoshito|penisola"
  and url NOT REGEXP "sex-on-the-beach|sexage|sexy( |-)?xmas"

  /* and also excluding these products, which are real */
  and code != '4901588160819' /* cacaball */
  and code != '8413209325003' /* mojicacas */
  and code != '3760168112003' /* velouté de cacasse à cul nu */
  and code != '8606107718514' /* cacanski chips */
  and code != '5901549275131' /* caca koko */
  and code != '5601055312657' /* Kit Caça aos Ovos */

  and code != '3760182600142' /* le vin de merde */
  and code != '3760182600012' /* vin de merde */
  and code != '3760182600029' /* idem */
  and code != '3760182600036' /* idem */
  and code != '3760311102097' /* Bière de merde */
  and code != '3770007484031' /* Miel récolté à Merdignac */
  and code != '8030525002311' /* Fiasconaro Panettone Oro Verde */
  and code != '3478220003045' /* merda di can */
  and code != '5602131000161' /* Licor de merda Licor de leite */

  and code != '3770013046032' /* pipi joli */
  and code != '3850129064103' /* pipi */
  and code != '3859893637001' /* pipi */
  and code != '3870183400006' /* pipi */
  and code != '3870183400167' /* pipi */
  and code != '3870183400396' /* pipi */
  and code != '8606105495882' /* pipi extra */
  and code != '9004145027107' /* pipifein */

  and code != '5410293620116' /* couilles de singe */
  and code != '5410293620123' /* couilles de singe - monkey balls */
  and code != '5425002713386' /* couilles de singe */
  and code != '5425002710507' /* véritable couille de singe */

  and code != '3760042798347' /* no sex for butterfly */
  and code != '4049162180232' /* sex Gewürz */
  and code != '3760238194410' /* sex in a canoe */
  and code != '3760238194403'
  and code != '0684746400074' /* sex on the beach */
  and code != '0684746400555'
  and code != '3014409005884'
  and code != '3760057471952'
  and code != '4003310017474'
  and code != '8413425013661'
  and code != '8435117988194'
  and code != '3760153932425' /* Houmousexuel */
  and code != '0642860300236' /* Dark rich & sexy */
  and code != '3700389713924' /* goût sexy */
  and code != '4006814002854' /* sexy xmas */
  and code != '3700444604303' /* sexy candy explosion */
  and code != '4029811280186' /* sexy sucette */
  and code != '4029811290888' /* sexy candy */
  and code != '4049162112257' /* sexy pfeffermühle */
  and code != '8436553981527' /* Infusión Descaradamente Sexy */
  and code != '3662051008311' /* sexy mojito */
  and code != '3770010353027' /* sexe on fire */
  and code != '3286010009036' /* tonifiant sexuel */
  and code != '3286010066114' /* tonifiant sexuel */
  and code != '7610815065861' /* sexy dark swiss chocolate */
  and code != '0815784020171' /* sex dust */
  and code != '0815784020928' /* sex dust */
  and code != '4029811179961' /* sex pasta */
  and code != '8436562014773' /* slow sex */

  and code != '5430001715002' /* urine (beer) */
  and code != '0658010116633' /* raw probiotic vaginal care */
  and code != '5902448150994' /* vaginal beer */

  and code != '3700281631890' /* les zizibons */
  and code != '3700281615746' /* pasta zizi */
  and code != '3760150337841' /* zizi top */
  and code != '4029811142163' /* pastille zizi */
  and code != '3700281637380' /* sucette zizi */
  and code != '3700281603569' /* sucette zizi */

  and code != '5032490000227' /* bancock */
  and code != '9421008690221' /* big cock energy drink */
  and code != '0714834004287' /* cock cola */
  and code != '0055270844168' /* cock soup mix */
  and code != '0027246108314' /* cock soup mix */
  and code != '8004194041049' /* le cock */

  and code != '4006989407720' /* fuck off vodka */
  and code != '3760262450032' /* big fucking IPA */
  and code != '5902837741031' /* fucking delicious cookie */
  and code != '5060243075512' /* fucking strong coffee */
  and code != '0869043000213' /* calm the fuck down tea */
  and code != '8718868184313' /* just fucking good wine */
  and code != '3760299631251' /* fuck le virus */
  and code != '3770004763382' /* fucking regalade */
  and code != '0850228006236' /* full as fuck */

  and code != '3760243920639' /* Bière Rotten Christmas */
  and code != '00067546'      /* rotten rolls */
  and code != '0022000277817' /* rotten zombies */

  and code != '0689076701846' /* special shit */
  and code != '0689076701945' /* good shit */
  and code != '0713757333931' /* bull shit steak seasoning */
  and code != '0718122227877' /* BBQ shit */
  and code != '0748252027283' /* shit seasoning / chicken shit */
  and code != '4014600204887' /* shit happens */
  and code != '0894323000034' /* don't be a chicken shit */
  and code != '4903326112258' /* shittori matcha */

  and code != '0071567999403' /* stink bug */
  and code != '0893511002027' /* stinkin' good */
  and code != '0844527036674' /* love stinks sugar cookie kit */

  and code != '00149'         /* penis pasta */
  and code != '03346442'      /* penis pop */
  and code != '5022782000936' /* Penis Pasta */
  and code != '5022782333607' /* Willie Lollipop With Penis Shape */
  and code != '5022782099442' /* Jelly Willies Penis Gums */
  and code != '5022782888749' /* Cola Willies Penis Gums */
  order by last_modified_t desc limit 500