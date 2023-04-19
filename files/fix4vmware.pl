#!/usr/bin/perl -w

use strict;
use XML::LibXML;

my $xmlns="http://schemas.dmtf.org/ovf/envelope/1";
my $xmlns_vmw="http://www.vmware.com/schema/ovf";
my $xmlns_vssd="http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/CIM_VirtualSystemSettingData";
my $file = $ARGV[0];

my $parser = XML::LibXML->new;
open my $fh, "$file" or die "Failed to open $file: $!";
my $string = join('', <$fh>);
my $xml;
eval {
    $xml = $parser->parse_string($string, { no_blanks => 1 });
};
if ($@) {
    my $err = $@;
    die "Failed to parse file $file: $@";
};
close $fh;

#print $xml->toString;

my $root = $xml->documentElement;
$root->setNamespace($xmlns_vmw, 'vmw', 0);

foreach my $oss ($root->getElementsByTagNameNS($xmlns, 'OperatingSystemSection')) {
    # add attributes  ovf:version="11" vmw:osType="debian11_64Guest"
    # to /Envelope/VirtualSystem/OperatingSystemSection
    $oss->setAttributeNS($xmlns, 'version', '11');
    $oss->setAttributeNS($xmlns_vmw, 'osType', 'debian11_64Guest');

    # remove all subelements from /Envelope/VirtualSystem/OperatingSystemSection except Info
    foreach my $child ($oss->childNodes()) {
	next if ($child->nodeName eq 'Info');
#	next if (($child->nodeName eq '#text') and $child->parentNode->nodeName);
	$oss->removeChild($child);
    }
};

# change text value of /Envelope/VirtualSystem/VirtualHardwareSection from virtualbox-2.2 to vmx-7
foreach my $vhs ($root->getElementsByTagNameNS($xmlns_vssd, 'VirtualSystemType')) {
    my $value = $vhs->textContent;
    die "Node ".$vhs->nodePath."/".$vhs->nodeName.
	" have different value than expected virtualbox-2.2. Terminating" if ($value ne 'virtualbox-2.2');

    $vhs->removeChildNodes;
    $vhs->appendText('vmx-7')
};

print $xml->toString;
