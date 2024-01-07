// Transcipt Download Button
function downloadText(textType, filename, textLocation) {
  // Get the translation element
  var translationElement = $(textLocation);
  // Get the translation content in HTML format
  var translationContentHTML = translationElement.html();

  // Convert HTML to plain text format
  var translationContentText = $("<div>").html(translationContentHTML).text();
  // Insert line breaks using regular expression
  var formattedTranslation = translationContentText.replace(/<br>/g, '\n');

  // Create a Blob (Binary Large Object) to store the text content
  var blob = new Blob([formattedTranslation], { type: "text/plain" });

  // Create a download link
  var link = document.createElement("a");
  // Set up the download filename
  link.download = textType + "_" + filename + ".txt";

  // Create a URL for the Blob and set it as the link's href attribute
  link.href = window.URL.createObjectURL(blob);

  // Append the link to the document
  document.body.appendChild(link);
  // Trigger the click event of the link to initiate the download
  link.click();
  // Remove the link from the document
  document.body.removeChild(link);
}

// Google Translate API
function translateText(text, targetLanguage) {
  return new Promise((resolve, reject) => {
    // if targetLanguage is unselected (null)，return Reminding wording
    if (!targetLanguage) {
      console.log('Target language is empty.');
      reject('Please select a language to translate.');
    }

    const apiKey = "AIzaSyB7-AoI-My5fcPWI74voWYCA6qwvTEQsC4"; // Google Translate API Key
    const apiUrl = `https://translation.googleapis.com/language/translate/v2?key=${apiKey}`;

    // Set up the translating params
    const params = {
      q: text,
      target: targetLanguage,
    };

    // Sending POST Request
    fetch(apiUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(params),
    })
      .then(response => response.json())
      .then(data => {
        // Handle Translation Request
        const translatedText = data.data.translations[0].translatedText;
        // console.log('Translated Text:', translatedText);
        resolve(translatedText);
      })
      .catch(error => {
        console.error('Error:', error);
        reject('Translation error.');
      });
  });
}

// Translate Button
$(document).ready(function() {
  $("#translateButton").click(function() {
    // Get the value of the dropdown menu
    var selectedLanguage = $("#sel1").val();

    // Get transcript content to translate
    // Get the transcript element
    var textLocation = ".list-group.transcript-content.pt-1 div[data-new-content]";
    var transcriptElement = $(textLocation);
    // Get the transcript content in HTML format
    var transcriptContentHTML = transcriptElement.html();

    // Convert HTML to plain text format
    var transcriptContentText = $("<div>").html(transcriptContentHTML).text();
    // Insert line breaks using regular expression
    var formattedTranscript = transcriptContentText.replace(/<br>/g, '\n');

    // Get the value of data-lang-dict-value
    var langDict = $("#translateButton").data("lang-dict-value");

    const textToTranslate = formattedTranscript;
    const targetLanguage = langDict[selectedLanguage]; // The language code to translate into, e.g., 'es' for Spanish

    // Change HTML content
    // Call the translation function, handling asynchronously with a Promise
    translateText(textToTranslate, targetLanguage)
    .then(function(translatedText) {
      // Rewrite HTML content
      $(".translate-content div.row div[data-new-content='episode_translation']").html(translatedText);
      // console.log("Translated Text:", translatedText);
    })
    .catch(function(error) {
      console.error('Translation error:', error);
    });
  });
});
