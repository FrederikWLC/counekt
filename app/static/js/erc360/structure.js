// Change tab
$(document).on('click', '#structure-tabs ul li', function() {
	console.log("STRUCTURE");
	if ($(this).hasClass('is-active')) {
		$('#structure-tabs ul li').removeClass('is-active');
	}

	else {
	$('#structure-tabs ul li').removeClass('is-active');
	$(this).addClass('is-active');
	$(".structure-tab-content").addClass('vanish');
	$($(this).data('content')).removeClass('vanish');
	}
});

$(document).on('keypress','#deposit-amount-input',function(event) {
    var key = event.keyCode || event.charCode;
    console.log(key);
    if (key < 48 || key > 57) {
      if (key == 44 || key == 46) {
      	const string = $('#deposit-amount-input').val()
      	if (string.includes(',') || string.includes('.')) {
      		return false;
      	}
      	return true;
      }
      if (key == 13) {
        $(this).blur();
      }
      return false;
    }

  });

function formatDepositAmountInput(string) {

	if (string.startsWith(',') || string.startsWith('.')) {
	  string = '0' + string;
	}

  return string.replace(/^0+/,'0').replace(/^0(?=[1-9])/,'');
}

$(document).on('blur input','#deposit-amount-input',function(event) {
	$('#deposit-amount-input').val(formatDepositAmountInput($('#deposit-amount-input').val()));
 });



$(document).on('click', '#deposit-button', function() {
	changeToDeposit();
});

$(document).on('click', '#deposit', function() {
	openDepositWindow();
});


async function openDepositWindow() {
	// Replace 'recipientAddress' with the Ethereum address you want to send funds to
	if (!makeSureWalletConnected()) {return;}

	const recipientAddress = $("#erc360-address").text();
	const web3 = getWeb3Provider();
	const network = await web3.eth.net.getNetworkType();
	console.log(network == "main");
	const accounts = await web3.eth.getAccounts().catch((e) => console.log(e.message));

	let send = web3.eth.sendTransaction({from:accounts[0],to:recipientAddress, value:web3.utils.toWei("0.1", "ether")}).catch((error) => {
      console.error(error);
    });
}

function update_structure(address) {
        console.log("updating...");
        $("#reload-structure").prop('disabled', true);$("#reload-structure").addClass('is-loading');
        $.post("/€"+address+"/update/structure/",function(response) {
                $.get("/€"+address+"/get/structure/", function(structure, status) {
                        $("#structure-modal").replaceWith(structure);
                        $("#reload-structure").removeClass('is-loading').prop('disabled', false);
                        console.log("success!");
        });
        });
        
}

