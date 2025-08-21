
   window.addEventListener('message', function(event) {
       const data = event.data;
       const mugshotContainer = document.getElementById('mugshot-container');
       const mugshotImage = document.getElementById('mugshot-image');

       if (data.action === 'showMugshot') {
           if (data.url && data.url !== '') {
               mugshotImage.src = data.url;
               mugshotContainer.style.display = 'flex';
               document.getElementById('close-button').focus();
           }
       } else if (data.action === 'closeMugshot') {
           mugshotContainer.style.display = 'none';
           mugshotImage.src = '';
           fetch('https://phils-mdt/closeMugshot', {
               method: 'POST',
               headers: { 'Content-Type': 'application/json' },
               body: JSON.stringify({})
           });
       }
   });

   document.getElementById('close-button').addEventListener('click', function() {
       document.getElementById('mugshot-container').style.display = 'none';
       document.getElementById('mugshot-image').src = '';
       fetch('https://phils-mdt/closeMugshot', {
           method: 'POST',
           headers: { 'Content-Type': 'application/json' },
           body: JSON.stringify({})
       });
   });

   document.addEventListener('keydown', function(event) {
       if (event.key === 'Escape') {
           document.getElementById('mugshot-container').style.display = 'none';
           document.getElementById('mugshot-image').src = '';
           fetch('https://phils-mdt/closeMugshot', {
               method: 'POST',
               headers: { 'Content-Type': 'application/json' },
               body: JSON.stringify({})
           });
       }
   });
   