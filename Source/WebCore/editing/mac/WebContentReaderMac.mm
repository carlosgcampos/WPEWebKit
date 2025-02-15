/*
 * Copyright (C) 2006-2017 Apple Inc. All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * THIS SOFTWARE IS PROVIDED BY APPLE INC. ``AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED.  IN NO EVENT SHALL APPLE INC. OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
 * PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY
 * OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "config.h"
#import "WebContentReader.h"

#import "ArchiveResource.h"
#import "Document.h"
#import "DocumentFragment.h"
#import "DocumentLoader.h"
#import "Editing.h"
#import "Editor.h"
#import "EditorClient.h"
#import "File.h"
#import "FragmentScriptingPermission.h"
#import "FrameLoader.h"
#import "FrameLoaderClient.h"
#import "HTMLAnchorElement.h"
#import "HTMLAttachmentElement.h"
#import "HTMLNames.h"
#import "LegacyWebArchive.h"
#import "MIMETypeRegistry.h"
#import "RuntimeEnabledFeatures.h"
#import "Settings.h"
#import "Text.h"
#import "WebCoreNSURLExtras.h"
#import "markup.h"

namespace WebCore {

bool WebContentReader::readFilenames(const Vector<String>& paths)
{
    if (paths.isEmpty())
        return false;

    if (!frame.document())
        return false;
    Document& document = *frame.document();

    fragment = document.createDocumentFragment();

    for (auto& text : paths) {
#if ENABLE(ATTACHMENT_ELEMENT)
        if (RuntimeEnabledFeatures::sharedFeatures().attachmentElementEnabled()) {
            auto attachment = HTMLAttachmentElement::create(HTMLNames::attachmentTag, document);
            attachment->setFile(File::create([[NSURL fileURLWithPath:text] path]).ptr());
            fragment->appendChild(attachment);
            continue;
        }
#else
        auto paragraph = createDefaultParagraphElement(document);
        paragraph->appendChild(document.createTextNode(userVisibleString([NSURL fileURLWithPath:text])));
        fragment->appendChild(paragraph);
#endif
    }

    return true;
}

bool WebContentReader::readHTML(const String& string)
{
    String stringOmittingMicrosoftPrefix = string;

    // This code was added to make HTML paste from Microsoft Word on Mac work, back in 2004.
    // It's a simple-minded way to ignore the CF_HTML clipboard format, just skipping over the
    // description part and parsing the entire context plus fragment.
    if (string.startsWith("Version:")) {
        size_t location = string.findIgnoringCase("<html");
        if (location != notFound)
            stringOmittingMicrosoftPrefix = string.substring(location);
    }

    if (stringOmittingMicrosoftPrefix.isEmpty())
        return false;

    if (!frame.document())
        return false;
    Document& document = *frame.document();

    fragment = createFragmentFromMarkup(document, stringOmittingMicrosoftPrefix, emptyString(), DisallowScriptingAndPluginContent);
    return fragment;
}

bool WebContentReader::readURL(const URL& url, const String& title)
{
    if (url.string().isEmpty())
        return false;

    auto anchor = HTMLAnchorElement::create(*frame.document());
    anchor->setAttributeWithoutSynchronization(HTMLNames::hrefAttr, url.string());
    anchor->appendChild(frame.document()->createTextNode([title precomposedStringWithCanonicalMapping]));

    fragment = frame.document()->createDocumentFragment();
    fragment->appendChild(anchor);
    return true;
}

}
