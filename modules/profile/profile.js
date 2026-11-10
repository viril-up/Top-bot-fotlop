/* Viril Profile module
 * Keeps profile-specific FAQ interactions isolated from the main app.
 * Existing account, profile-edit, settings, reset and delete handlers remain
 * in the main application because they share its auth/state lifecycle.
 */
(()=>{'use strict';
  const faq=document.getElementById('profileFaq');
  const open=document.getElementById('openFaq');
  const close=document.getElementById('closeFaq');
  if(!faq||!open||!close)return;

  const setFaqOpen=(isOpen)=>{
    faq.classList.toggle('hidden',!isOpen);
    open.setAttribute('aria-expanded',String(isOpen));
    faq.setAttribute('aria-hidden',String(!isOpen));
    if(isOpen){
      faq.scrollIntoView({behavior:window.matchMedia('(prefers-reduced-motion: reduce)').matches?'auto':'smooth',block:'nearest'});
      const firstQuestion=faq.querySelector('summary');
      if(firstQuestion)firstQuestion.setAttribute('tabindex','0');
    }else{
      open.focus({preventScroll:true});
    }
  };

  open.setAttribute('aria-controls','profileFaq');
  open.setAttribute('aria-expanded','false');
  faq.setAttribute('aria-hidden','true');
  open.addEventListener('click',()=>setFaqOpen(faq.classList.contains('hidden')));
  close.addEventListener('click',()=>setFaqOpen(false));
  faq.addEventListener('keydown',event=>{
    if(event.key==='Escape'&&!faq.classList.contains('hidden'))setFaqOpen(false);
  });
})();