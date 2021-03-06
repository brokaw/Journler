
/*
 Redistribution and use in source and binary forms, with or without modification, are permitted
 provided that the following conditions are met:
 
 * Redistributions of source code must retain the above copyright notice, this list of conditions
 and the following disclaimer.
 
 * Redistributions in binary form must reproduce the above copyright notice, this list of conditions
 and the following disclaimer in the documentation and/or other materials provided with the
 distribution.
 
 * Neither the name of the author nor the names of its contributors may be used to endorse or
 promote products derived from this software without specific prior written permission.
 
 THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
 WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
 PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR
 ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT
 LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR
 TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF
 ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
*/

// Basically, you can use the code in your free, commercial, private and public projects
// as long as you include the above notice and attribute the code to Philip Dow / Sprouted
// If you use this code in an app send me a note. I'd love to know how the code is used.

// Please also note that this copyright does not supersede any other copyrights applicable to
// open source code used herein. While explicit credit has been given in the Journler about box,
// it may be lacking in some instances in the source code. I will remedy this in future commits,
// and if you notice any please point them out.

#import "MissingFileController.h"

#import "JournlerResource.h"
#import "JournlerJournal.h"
#import "JournlerEntry.h"

#import <SproutedUtilities/SproutedUtilities.h>
#import <SproutedInterface/SproutedInterface.h>

/*
#import "NDAlias.h"
#import "NDAlias+AliasFile.h"
#import "NSImage_PDCategories.h"
#import "NSString+PDStringAdditions.h"

#import "JournlerGradientView.h"
*/

@implementation MissingFileController

- (id) initWithResource:(JournlerResource*)aResource
{
	if ( self = [super init] )
	{
		[self setResource:aResource];
		[NSBundle loadNibNamed:@"MissingResourceError" owner:self];
	}
	
	return self;
}

- (void) awakeFromNib 
{
	NSInteger eBorders[4] = {1,0,1,0};
	[errorBar setBordered:YES];
	[errorBar setBorderColor:[NSColor colorWithCalibratedRed:155.0/255.0 green:155.0/255.0 blue:155.0/255.0 alpha:1.0]];
	[errorBar setBorders:eBorders];
	
	if ( [self resource] != nil )
		[missingFileImageView setImage:[[self resource] valueForKey:@"icon"]];
}

- (void) dealloc
{
	[errorContent release];
	[locateAccessory release];
	[resource release];
	
	[super dealloc];
}

#pragma mark -

- (id) delegate
{
	return delegate;
}

- (void) setDelegate:(id)anObject
{
	delegate = anObject;
}

- (JournlerResource*) resource
{
	return resource;
}

- (void) setResource:(JournlerResource*)aResource
{
	if ( resource != aResource )
	{
		[resource release];
		resource = [aResource retain];
		
		if ( missingFileImageView != nil )
			[missingFileImageView setImage:[resource valueForKey:@"icon"]];
	}
}

#pragma mark -

- (NSView*) contentView
{
	return errorContent;
}

#pragma mark -

- (IBAction)returnToEntry:(id)sender
{
	if ( [[self delegate] respondsToSelector:@selector(fileController:wantsToNavBack:)] )
		[[self delegate] fileController:self wantsToNavBack:[self resource]];
	else
		NSBeep();
}

- (IBAction) deleteMissingFile:(id)sender
{
	if ( [[self delegate] respondsToSelector:@selector(fileController:willDeleteResource:)] )
		[[self delegate] fileController:self willDeleteResource:[self resource]];
	
	[[[self resource] journal] deleteResource:[self resource]];
}

- (IBAction) searchForMissingFile:(id)sender
{
	NSBeep();
	return;
}

- (IBAction) locateMissingFile:(id)sender
{
	NSInteger result;
    NSOpenPanel *oPanel = [NSOpenPanel openPanel];
	
	[oPanel setAccessoryView:locateAccessory];
    result = [oPanel runModalForDirectory:nil file:nil types:nil];
	
    if (result == NSOKButton) 
	{
        BOOL success = YES;
		NSString *filename = [oPanel filename];
		JournlerResource *theResource = [self resource];
		
		NSFileManager *fm = [NSFileManager defaultManager];
		NewResourceCommand operation = ( [locateOption selectedTag] == 0 ? kNewResourceForceLink : kNewResourceForceCopy );
		
		NSString *resourcePath = [theResource path];
		NSString *thumbnailPath = [theResource _pathForFileThumbnail];
		NSString *newResourcePath = [[[[theResource entry] resourcesPathCreating:NO] 
		stringByAppendingPathComponent:[filename lastPathComponent]] pathWithoutOverwritingSelf];
		
		// delete the current resource file
		if ( [fm fileExistsAtPath:resourcePath] )
		{
			if ( ![fm removeFileAtPath:resourcePath handler:self] )
			{
				success = NO;
				NSLog(@"%s - unable to delete file at path %@", __PRETTY_FUNCTION__, resourcePath);
			}
		}
		else
		{
			//NSLog(@"%s - no file to delete at path %@", __PRETTY_FUNCTION__, resourcePath);
		}
		
		
		// delete the current resource file
		if ( [fm fileExistsAtPath:thumbnailPath] )
		{
			if ( ![fm removeFileAtPath:thumbnailPath handler:self] )
			{
				success = NO;
				NSLog(@"%s - unable to delete thumnail at path %@", __PRETTY_FUNCTION__, thumbnailPath);
			}
		}
		else
		{
			//NSLog(@"%s - no thumbnail to delete at path %@", __PRETTY_FUNCTION__, thumbnailPath);
		}
		
		
		// copy the new resource file
		if ( operation == kNewResourceForceCopy ) 
		{
			// actually copy the file
			if ( ![fm copyPath:filename toPath:newResourcePath handler:self] )
			{
				success = NO;
				NSLog(@"%s - unable to copy %@ to %@", __PRETTY_FUNCTION__, filename, newResourcePath);
			}
			else
			{
				// set the creation date on the copied file
				NSDate *creation_date = [[fm fileAttributesAtPath:filename traverseLink:NO] objectForKey:NSFileCreationDate];
				if ( creation_date == nil ) creation_date = [NSDate date];
				NSDictionary *file_attrs = [NSDictionary dictionaryWithObject:creation_date forKey:NSFileCreationDate];
				[fm changeFileAttributes:file_attrs atPath:newResourcePath];
			}
		}
		
		// or link to the new resource file
		else if ( operation == kNewResourceForceLink )
		{
			// actually create the link
			NDAlias *alias = [[NDAlias alloc] initWithPath:filename];
			if ( ![alias writeToFile:newResourcePath] ) 
			{
				success = NO;
				NSLog(@"%s - unable to link %@ to %@", __PRETTY_FUNCTION__, filename, newResourcePath);
			}
		}
		
		// check for errors
		if ( success == NO )
		{
			NSBeep();
		}
		else
		{
			// otherwise reset some of the attributes on the resource
			[theResource setValue:[[newResourcePath lastPathComponent] stringByDeletingPathExtension] forKey:@"title"];
			[theResource setValue:[newResourcePath lastPathComponent] forKey:@"filename"];
			[theResource setValue:[newResourcePath stringByAbbreviatingWithTildeInPath] forKey:@"relativePath"];
			[theResource loadIcon];
			
			if ( [[self delegate] respondsToSelector:@selector(fileController:didRelocateResource:)] )
				[[self delegate] fileController:self didRelocateResource:theResource];
		}
	}
}

#pragma mark -
#pragma mark File Manager Delegation

- (BOOL)fileManager:(NSFileManager *)manager shouldProceedAfterError:(NSDictionary *)errorInfo 
{
	NSLog(@"\n%s - file manager error working with path: %@\n", __PRETTY_FUNCTION__, [errorInfo description]);
	return NO;
}

- (void)fileManager:(NSFileManager *)manager willProcessPath:(NSString *)path 
{
	return;
}

@end
