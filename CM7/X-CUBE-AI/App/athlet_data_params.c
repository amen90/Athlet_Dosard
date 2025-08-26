/**
  ******************************************************************************
  * @file    athlet_data_params.c
  * @author  AST Embedded Analytics Research Platform
  * @date    2025-08-26T00:21:38+0200
  * @brief   AI Tool Automatic Code Generator for Embedded NN computing
  ******************************************************************************
  * Copyright (c) 2025 STMicroelectronics.
  * All rights reserved.
  *
  * This software is licensed under terms that can be found in the LICENSE file
  * in the root directory of this software component.
  * If no LICENSE file comes with this software, it is provided AS-IS.
  ******************************************************************************
  */

#include "athlet_data_params.h"


/**  Activations Section  ****************************************************/
ai_handle g_athlet_activations_table[1 + 2] = {
  AI_HANDLE_PTR(AI_MAGIC_MARKER),
  AI_HANDLE_PTR(NULL),
  AI_HANDLE_PTR(AI_MAGIC_MARKER),
};




/**  Weights Section  ********************************************************/
AI_ALIGNED(32)
const ai_u64 s_athlet_weights_array_u64[369] = {
  0xbdbfd84b3e75fc5bU, 0x3ead1d57beab14c9U, 0xbea0ccc03ea51d48U, 0x3e9476dfbec759f9U,
  0xbec453723c3219e5U, 0x3e915a913e5b1590U, 0x3e594f323dcb36f5U, 0xbec81a2cbea54f4dU,
  0xbeb1fcd3be764765U, 0x3eac01323e568d99U, 0xbd80ee0b3e04f197U, 0x3e9ed96ebe8434d9U,
  0x3df84b98bd8c6b75U, 0x3ea0f1963d194b98U, 0x3e96b799be92f31cU, 0x3e9485623ebdcdfbU,
  0xbe23c768bd2638faU, 0x3e9698453e9786feU, 0x3e362dc33e5c011cU, 0xbe31ea853d443792U,
  0xbe366568be2aebceU, 0xbe42907bbd38e136U, 0x3eb9e9c93edc2cb7U, 0x3db132423e554a78U,
  0xbee741d23e5fe7c2U, 0xbe9b7bb8be2133adU, 0x3d98ca01bca6582aU, 0xbe947ed3be9fe4c2U,
  0xbea930af3ee35729U, 0xbe42507bbedbf44aU, 0x3e0167543e972e00U, 0xbd7a84db3d6d2280U,
  0x3db52259bc093e6aU, 0x3e42ed89be3f5695U, 0x3d3f0eb6bdce482dU, 0x3e8b4eae3d6f657dU,
  0x3e123a3dbee6877bU, 0xbe73d64d3e6a62d0U, 0xbd64cdcb3e22fcceU, 0xbe39cce1bd4133b0U,
  0x3ebc8becbe236669U, 0xbef242d2beceefe2U, 0x3e83c7ac3e6655f5U, 0xbed071c33ed1c76fU,
  0x3e5ce03abec611d6U, 0xbd28cba5bd910ed1U, 0xbcc367303e5b9cfdU, 0x3e2ebe90bd7e598bU,
  0xbea682debe55b737U, 0xbe9928893eb71bbbU, 0xbd445f70be38a433U, 0xbe18d6dc3ed0ef89U,
  0x3deb66b73ea0012eU, 0x3eb6c87fbe0a511bU, 0x3d6a32453e724bd1U, 0x3e504da8be6c1ce8U,
  0x3d0ca50e3e2384ddU, 0x3ebd0263bd1f4c2cU, 0x3df410603eb15140U, 0xbe8cca2bbeddef61U,
  0xbdf603953e84ccc3U, 0xbe6be609beb36426U, 0x3e795aadbeb96243U, 0xbd8ec45f3ec29bbfU,
  0x3edd4a8dbdd67e57U, 0xbebc00603e63f51bU, 0xbe8247503ee9e4bdU, 0xbe83082ebe8d1211U,
  0x3e709ab13e9867d5U, 0x3eb653b73e3e7cc9U, 0xbe9764abbd39b878U, 0xbe67b1a93ed3750dU,
  0x3eb7f3ecbe0b78f5U, 0x3dcfd8fa3e702ee1U, 0xbe07e4283c2d7448U, 0x3ca0198cbe84f5a4U,
  0xbc5a831dbe33507dU, 0x3eab877cbddb3571U, 0xbea6b01f3d821fc4U, 0x3e8c126e3ed58377U,
  0x3d2721d7bd1ebb99U, 0xbd59956dbcb9a482U, 0xbd131425bd27eaf8U, 0x3ba46ce8bd5bbcd3U,
  0x3c77f59dbbcb567eU, 0x3dfa48f63c2446ffU, 0xbbc3c437bb6e1dd0U, 0x3dadad8d3daa2322U,
  0x3da5c34c3d983740U, 0xbc1493e63cc646b4U, 0xbd27fc203d3d7193U, 0x3da274ec3d5d0257U,
  0x3d4d39c4bcd6e9f1U, 0x3c29906b3cf81542U, 0x3cf0c80b3d28874aU, 0xbcb05678bcee873bU,
  0xbc9fdebbbb8db304U, 0x3d3d43cabe22d977U, 0xbe1f1bbbbe3b3011U, 0xbcc148d8bd10f123U,
  0xbe8b2046be7123feU, 0x3edac9dc3e522830U, 0xbe9d04003e03928bU, 0x3e6c8d48bdca05aaU,
  0x3ec799133c8911dcU, 0x3e67239d3dae265cU, 0xbd7f78c8be6de9ccU, 0x3ee65cca3e24fff8U,
  0x3e436d0c3e54abd0U, 0xbe65ff8e3d800a16U, 0xbe43521c3e50d469U, 0x3ea189133db60a48U,
  0x3d65b20b3dc0ab6fU, 0x3e645f2f3ca8a286U, 0x3e135f5cbe7fc6b5U, 0x3da029c2beb1aee3U,
  0xbe30ad2dbe42ffcbU, 0xbe088c9abe9a8b0eU, 0xbe4b73f2be54c37eU, 0xbd9841e83e267a51U,
  0x3c8a90e73de347f3U, 0xbeb78c303e44c12aU, 0xbea6d5433aaf104cU, 0xbe4bc9483e9692a1U,
  0x3e98d8843e83d839U, 0xbe98eb833eaf03a6U, 0xbca30a55be04d1fdU, 0x3d030f80be7f210fU,
  0x3ec900c03e29f2d1U, 0xbd9aba1c3be64bd4U, 0xbe16feffbe266efeU, 0xbe19be7fbe642c83U,
  0xbd22e3a5be8035fdU, 0xbec576893e3df7f8U, 0x3e9468c7bce77e3bU, 0xbe84252dbec69375U,
  0xbe26e15f3e7f6c3eU, 0xbe7056a83caa31ccU, 0xbd9a9e713ea16895U, 0xbe9d2abebea6b971U,
  0xbd0b0e9d3e4b49cbU, 0x3e26e9213e764d2fU, 0x3eb557b83ed16cd1U, 0x3e03ac08be8f15d9U,
  0x3ec042683c49d77eU, 0xbe77175e3d906643U, 0x3df80257bdad813eU, 0xbd9748ce3e162b0aU,
  0xbd5c129f3e188db7U, 0xbd32960abe2ceed2U, 0x3da08ad6be018ff8U, 0x3ddc14c43c794d74U,
  0xbeccb19ab97794a4U, 0x3ec8b2e3be33e0fbU, 0x3e24cb573d6eb1faU, 0xbe6846533eafe403U,
  0x3d871745be902937U, 0xbe75b2f13ebe3b58U, 0x3c47488ebcbae402U, 0x3e1aa95ebe89dc06U,
  0xbe4ac6843b0ad25dU, 0x3e7b25fa3e60eb5eU, 0x3e922c13bdbbdea3U, 0xbeb6acdd3e7d6fd6U,
  0xbde297643e12081aU, 0x3e6e076b3bc993dfU, 0x3e313730bd959af0U, 0x3e5615353cce4f9fU,
  0xbea6ff5bbe338dddU, 0x3d623881be07b348U, 0x3c7e5931beaf0b21U, 0x3e2f2e37beb9ced4U,
  0xbdc46caf3e9a0a71U, 0xbdd338073e0e96d8U, 0x3e5cae0c3d9055e2U, 0x3daa82b43e7dc23dU,
  0x3ea2833f3de4db41U, 0x3c3bc862bd9964eeU, 0xbe7af56e3eb50bd7U, 0xbe1bdbd1bda84a30U,
  0x3e8cb3713e9e7f52U, 0xbe7a07083e43a3aaU, 0xbe23cda1be141439U, 0xbec7dbc9bec8ecb2U,
  0x3ddcf9453e71d05cU, 0x3ec26e09be652d34U, 0xbe8a40edbe08a2b7U, 0xbea83cf1be1719c5U,
  0x3d6efe5e3de1b682U, 0xbed81ac1be7fabc8U, 0x3d8f64fc3e1c0a45U, 0x3c2ef25fbdd4ca18U,
  0x3e862c34bda84225U, 0x3e2f56253e507552U, 0x3e49ab853d90b309U, 0x3e513ba33d5b2410U,
  0xbe5fb9a03cd564c4U, 0x3da86733be87e9ddU, 0xbe3bf3fcbd1b6250U, 0x3ed963b23df04529U,
  0xba5482953e708defU, 0x3e66ca79be1233ceU, 0x3e896576be4b80d1U, 0xbddbc14fbe76627dU,
  0x3ed57e8f3bca0af8U, 0x3e05103fbdb851b2U, 0x3eac0ee6bde4614bU, 0xbe8b316c3e0a075eU,
  0x3dcfc0cc3e4ddd44U, 0x3db23e1ebeac3b23U, 0x3e18aaf1bea2267fU, 0xbdf96f69bddc2667U,
  0x3b7482c4bcf85536U, 0xbd48442bbe59b6e9U, 0xbe76fdb3be829137U, 0xbc1104713ed80cb3U,
  0x3eafb0cb3ed14754U, 0x3e38c981be7f0583U, 0x3de3bf35bcbeaa1dU, 0xbe3851a23e4749a8U,
  0xbd406d6ebdfb165bU, 0xbc4f49883de38413U, 0x3e6ed342be867d6eU, 0x3ead8e57be0930baU,
  0x3de03720be6d152dU, 0xbe8cddef3c143779U, 0xbdf66decbe752ec6U, 0x3ea8f8e1bdce1c76U,
  0x3ec0d39a3ebb9d44U, 0x3e7ce70e3e168827U, 0x3e20ccd8be86dfcdU, 0x3e485b883d7addceU,
  0x3c6e870f3e92a599U, 0xbe9446e13e538cedU, 0xbe90348e3e074d07U, 0x3eca95ffbbe068f6U,
  0xbe09544d3d63f214U, 0xbe70bf47be60123eU, 0x3ed40ea83e1e52e5U, 0xbe841085bc8626f2U,
  0x3e8bf2cf3ea65c53U, 0xbe26f4fd3ec72454U, 0xbd299d963e464ac9U, 0xbcfe77513eb5c1f6U,
  0x3d593b87bd9ab1ccU, 0x3eac9b6abe982f92U, 0x3e6950933e24fae4U, 0x3e8abc16bdf5bb2dU,
  0x3eee74723ee583f9U, 0x3e0185ef3e87d287U, 0xbe4beed03e57f6b4U, 0x3ebeba0e3e81f984U,
  0x3ee0aea1bbe5c87eU, 0xbe99a8203d9460faU, 0x3db1dc54be0ad1e8U, 0x3eb9cc1b3d9b5594U,
  0x3e5f742fbd38dd72U, 0xbe37b2653d9efd1aU, 0x3d9a5b3abd804af3U, 0x3e91e3db3eac7e07U,
  0xbe4418d9bcc28e20U, 0xbc194b36bebffd34U, 0xbdb085553dde1a4cU, 0x3ed374e8be4003f0U,
  0x3dc6f9afbe3346efU, 0x3cb861883c7ef82aU, 0xbdcc5c50bd4b5dd9U, 0x3e94262f3eb5eddcU,
  0x3e9ffb813e4906f0U, 0x3dbdc5d53e270a43U, 0xbe857078bd09df18U, 0xbe5720123e20d509U,
  0xbe3566f83e4bfd8dU, 0x3d0e2df5be55d3e0U, 0x3db117b83ea90945U, 0x3e8bc3b5be34855cU,
  0xbdee11debdd13aaeU, 0xbe01f88dbeb1e373U, 0xbe5eddf1be75320dU, 0x3e50ed8bbe9f28e5U,
  0x3dd57066bea8b2c1U, 0xbe429c3cbe4e47b1U, 0x3d0196373d0ac3a9U, 0xbc70b3bb3e422068U,
  0x3e6173ad3cadc06dU, 0x3cee83743dbb0410U, 0x3e9c96233e894e53U, 0xbeb3a3d73d49ea32U,
  0xbe96ac19be3aeeadU, 0xbc90fc6d3e3ae4b5U, 0xbde8dcfebe26bf79U, 0x3e3816633e061e95U,
  0x3db9d8183e68da72U, 0xbe23170d3d7dfa02U, 0xbd35e1023e07815aU, 0xbdb048c0bd644cdcU,
  0x3ed06d7fbdfd1bffU, 0x3e625872bc2bcec6U, 0xbe23690d3e393173U, 0x3ed927293d847fceU,
  0x3e3ac0fb3be4a1abU, 0x3e990a343d0a5879U, 0x3d4446353d8e8e9aU, 0x3ccac2c13e802998U,
  0x3e471f0f3e6767f6U, 0x3da8f8f93e74a82eU, 0x3eb08578bcde7b53U, 0xbd7f5fcc3e64a41eU,
  0x3d4ff533be9d82bfU, 0xbe15ce3abe28fa22U, 0xbd7182c5beaa9d6bU, 0xbe2276bfbe825a77U,
  0xbd1c93c2bd21e353U, 0x3de014033ecfa992U, 0x3da662fbbe0c477fU, 0xbe980269bea74bf5U,
  0x3a06b1a43d9a826aU, 0x3e235a8b3ed07e7bU, 0x3d22046b3c2be063U, 0x3d850bc13e76224eU,
  0x3e30c490be8b3a51U, 0xbd025f75bec2889aU, 0x3e280f79bdc4074eU, 0xbe8ef6663e927f90U,
  0x3d5526203d63438aU, 0x3cdbc05d3e232fb5U, 0xbc8c7025be1a1592U, 0xbe9b0d73bde54280U,
  0x3e6b56ee3c58f117U, 0x3eb124ca3e0ae67cU, 0xbe99b276bd8d6747U, 0x3e6b2e0abdfb77beU,
  0xbe195ca33ce922e4U, 0xbcfd6c10be0bf5cfU, 0xbec2c1043da09730U, 0x3e2a599a3e839141U,
  0xbda6092a3e81a027U, 0xbec63df6be94345eU, 0x3ea13062bdbb47d6U, 0xbbdcc809bdca146eU,
  0x3da0d1abbe4b4368U, 0xbe99d0b3be169c7cU, 0x3e8b020dbe53c608U, 0x3e1afdeebe74a4daU,
  0x3e41fb63be11156aU, 0x3e84a7efbe4200f3U, 0xbe2145f73e75429fU, 0x3dbfbc323e0b099dU,
  0xbe80c1003ca3e79eU, 0x3e5a41313eca4939U, 0xbdbead793e6f3bffU, 0x3c09e59dbe6d07f9U,
  0xbd2d27ea3d9e7a89U, 0xbc523d5e3ceb8503U, 0xbcf524f9bd8454bbU, 0x3dd93d703d92c68aU,
  0x3dad0c2e3d8909daU, 0xbd1b5b303d7a0440U, 0xbcfbb6ea3d85b034U, 0xbcbee825bd7a3613U,
  0xba6a7648be0a1908U, 0x3f0bcac13ee6ca15U, 0x3f0c9cc63e83b1e0U, 0xbe0b9ce6be92baccU,
  0xbe2cdc49bf161a73U, 0x3efd0594bddcded2U, 0x3f0aac6cbe217d35U, 0x3df2f55b3d29d94eU,
  0xbd8213d5U,
};


ai_handle g_athlet_weights_table[1 + 2] = {
  AI_HANDLE_PTR(AI_MAGIC_MARKER),
  AI_HANDLE_PTR(s_athlet_weights_array_u64),
  AI_HANDLE_PTR(AI_MAGIC_MARKER),
};

