--!strict

--- ### r8limbs.luau
---
--- cc rig limb config for r6+2 rig
return {
	--- root
	RootPart = {
		meshid = "";
		scale = Vector3.new(1, 1, 1);
		hasface = false;

		humanoiddescriptionclothingproperties = {  };
		humanoiddescriptioncolorproperty = "";

		size = Vector3.new(2, 2, 1);
		transparency = 1;

		attachments = {
			RootAttachment = CFrame.new(0, 0, 0);

			RootJointAttachment0 = CFrame.new() * CFrame.fromOrientation(-math.pi/2, -math.pi, 0);
		};
		animationconstraints = {
			RootJoint = { attachment0 = "RootJointAttachment0"; attachment1 = "RootJointAttachment1"; iskinematic = true; };
		};
		ballsocketconstraints = {
			
		};
		ragdollcollision = false;
	};

	--- head
	Head = {
		meshid = "rbxassetid://15606744638";
		scale = Vector3.new(0.999, 0.999, 0.999);
		hasface = true;

		humanoiddescriptionclothingproperties = {  };
		humanoiddescriptioncolorproperty = "HeadColor";

		size = Vector3.new(1, 1, 1);
		transparency = 0;

		attachments = {
			FaceCenterAttachment = CFrame.new(0, 0, 0);
			FaceFrontAttachment = CFrame.new(0, 0, -0.65);
			HairAttachment = CFrame.new(0, 0.6, 0);
			HatAttachment = CFrame.new(0, 0.6, 0);

			NeckAttachment1 = CFrame.new(0, -0.5, 0) * CFrame.fromOrientation(-math.pi/2, -math.pi, 0);
		};
		animationconstraints = {
			
		};
		ballsocketconstraints = {
			
		};
		ragdollcollision = true;
	};
	--- torso
	Torso = {
		meshid = "rbxassetid://17580060252";
		scale = Vector3.new(1, 1, 1);
		hasface = false;

		humanoiddescriptionclothingproperties = { "Shirt"; "Pants"; };
		humanoiddescriptioncolorproperty = "TorsoColor";

		size = Vector3.new(2, 2, 1);
		transparency = 0;

		attachments = {
			BodyBackAttachment = CFrame.new(0, 0, 0.5);
			BodyFrontAttachment = CFrame.new(0, 0, -0.5);
			LeftCollarAttachment = CFrame.new(-1, 1, 0);
			NeckAttachment = CFrame.new(0, 1, 0);
			RightCollarAttachment = CFrame.new(1, 1, 0);
			WaistBackAttachment = CFrame.new(0, -1, 0.5);
			WaistCenterAttachment = CFrame.new(0, -1, 0);
			WaistFrontAttachment = CFrame.new(0, -1, -0.5);

			RootJointAttachment1 = CFrame.new(0, 0, 0) * CFrame.fromOrientation(-math.pi/2, -math.pi, 0);

			LeftHipAttachment0 = CFrame.new(-1, -1, 0) * CFrame.fromOrientation(0, -math.pi/2, 0);
			LeftShoulderAttachment0 = CFrame.new(-1, 0.5, 0) * CFrame.fromOrientation(0, -math.pi/2, 0);
			NeckAttachment0 = CFrame.new(0, 1, 0) * CFrame.fromOrientation(-math.pi/2, -math.pi, 0);
			RightHipAttachment0 = CFrame.new(1, -1, 0) * CFrame.fromOrientation(0, math.pi/2, 0);
			RightShoulderAttachment0 = CFrame.new(1, 0.5, 0) * CFrame.fromOrientation(0, math.pi/2, 0);
		};
		animationconstraints = {
			LeftHip = { attachment0 = "LeftHipAttachment0"; attachment1 = "LeftHipAttachment1"; iskinematic = true; };
			LeftShoulder = { attachment0 = "LeftShoulderAttachment0"; attachment1 = "LeftShoulderAttachment1"; iskinematic = true; };
			Neck = { attachment0 = "NeckAttachment0"; attachment1 = "NeckAttachment1"; iskinematic = true; };
			RightHip = { attachment0 = "RightHipAttachment0"; attachment1 = "RightHipAttachment1"; iskinematic = true; };
			RightShoulder = { attachment0 = "RightShoulderAttachment0"; attachment1 = "RightShoulderAttachment1"; iskinematic = true; };
		};
		ballsocketconstraints = {
			LeftHip = { attachment0 = "LeftHipAttachment0"; attachment1 = "LeftHipAttachment1"; };
			LeftShoulder = { attachment0 = "LeftShoulderAttachment0"; attachment1 = "LeftShoulderAttachment1"; };
			Neck = { attachment0 = "NeckAttachment0"; attachment1 = "NeckAttachment1"; };
			RightHip = { attachment0 = "RightHipAttachment0"; attachment1 = "RightHipAttachment1"; };
			RightShoulder = { attachment0 = "RightShoulderAttachment0"; attachment1 = "RightShoulderAttachment1"; };
		};
		ragdollcollision = true;
	};
	--- left
	LeftArm = {
		meshid = "rbxassetid://17580119910";
		scale = Vector3.new(1, 1, 1);
		hasface = false;

		humanoiddescriptionclothingproperties = { "Shirt" };
		humanoiddescriptioncolorproperty = "LeftArmColor";

		size = Vector3.new(1, 2, 1);
		transparency = 0;

		attachments = {
			LeftGripAttachment = CFrame.new(0, -1, 0);
			LeftShoulderAttachment = CFrame.new(0, 1, 0);

			LeftShoulderAttachment1 = CFrame.new(0.5, 0.5, 0) * CFrame.fromOrientation(0, -math.pi/2, 0);

			LeftWristAttachment0 = CFrame.new(0, -1, 0) * CFrame.fromOrientation(-math.pi/2, 0, 0);
		};
		animationconstraints = {
			LeftWrist = { attachment0 = "LeftWristAttachment0"; attachment1 = "LeftWristAttachment1"; iskinematic = true; };
		};
		ballsocketconstraints = {
			
		};
		ragdollcollision = true;
	};
	LeftHand = {
		meshid = "";
		scale = Vector3.new(1, 1, 1);
		hasface = false;

		humanoiddescriptionclothingproperties = {  };
		humanoiddescriptioncolorproperty = "";

		size = Vector3.new(1, 1, 1);
		transparency = 1;

		attachments = {
			LeftHandAttachment = CFrame.new(0, 0, 0);

			LeftWristAttachment1 = CFrame.new(0, 0, 0) * CFrame.fromOrientation(0, 0, 0);
		};
		animationconstraints = {
			
		};
		ballsocketconstraints = {
			
		};
		ragdollcollision = false;
	};
	LeftLeg = {
		meshid = "rbxassetid://17580119910";
		scale = Vector3.new(1, 1, 1);
		hasface = false;

		humanoiddescriptionclothingproperties = { "Pants" };
		humanoiddescriptioncolorproperty = "LeftLegColor";

		size = Vector3.new(1, 2, 1);
		transparency = 0;

		attachments = {
			LeftFootAttachment = CFrame.new(0, -1, 0);

			LeftHipAttachment1 = CFrame.new(-0.5, 1, 0) * CFrame.fromOrientation(0, -math.pi/2, 0);
		};
		animationconstraints = {
			
		};
		ballsocketconstraints = {
			
		};
		ragdollcollision = true;
	};
	--- right
	RightArm = {
		meshid = "rbxassetid://17580118235";
		scale = Vector3.new(1, 1, 1);
		hasface = false;

		humanoiddescriptionclothingproperties = { "Shirt" };
		humanoiddescriptioncolorproperty = "RightArmColor";

		size = Vector3.new(1, 2, 1);
		transparency = 0;

		attachments = {
			RightGripAttachment = CFrame.new(0, -1, 0);
			RightShoulderAttachment = CFrame.new(0, 1, 0);

			RightShoulderAttachment1 = CFrame.new(-0.5, 0.5, 0) * CFrame.fromOrientation(0, math.pi/2, 0);

			RightWristAttachment0 = CFrame.new(0, -1, 0) * CFrame.fromOrientation(-math.pi/2, 0, 0);
		};
		animationconstraints = {
			RightWrist = { attachment0 = "RightWristAttachment0"; attachment1 = "RightWristAttachment1"; iskinematic = true; };
		};
		ballsocketconstraints = {
			
		};
		motors = {

		};
		ragdollcollision = true;
	};
	RightHand = {
		meshid = "";
		scale = Vector3.new(1, 1, 1);
		hasface = false;

		humanoiddescriptionclothingproperties = {  };
		humanoiddescriptioncolorproperty = "";

		size = Vector3.new(1, 1, 1);
		transparency = 1;

		attachments = {
			RightHandAttachment = CFrame.new(0, 0, 0);

			RightWristAttachment1 = CFrame.new(0, 0, 0) * CFrame.fromOrientation(0, 0, 0);
		};
		animationconstraints = {
			
		};
		ballsocketconstraints = {
			
		};
		ragdollcollision = false;
	};
	RightLeg = {
		meshid = "rbxassetid://17580118235";
		scale = Vector3.new(1, 1, 1);
		hasface = false;

		humanoiddescriptionclothingproperties = { "Pants" };
		humanoiddescriptioncolorproperty = "RightLegColor";

		size = Vector3.new(1, 2, 1);
		transparency = 0;

		attachments = {
			RightFootAttachment = CFrame.new(0, -1, 0);

			RightHipAttachment1 = CFrame.new(0.5, 1, 0) * CFrame.fromOrientation(0, math.pi/2, 0);
		};
		animationconstraints = {
			
		};
		ballsocketconstraints = {
			
		};
		ragdollcollision = true;
	};
}